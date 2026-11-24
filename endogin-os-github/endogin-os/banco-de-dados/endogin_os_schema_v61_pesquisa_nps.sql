-- v61: respostas da pesquisa de NPS (formulário do Google) dentro do sistema.
-- 152 respostas, escala de 0 a 5. A nossa tabela é 0-10, então guardamos a nota
-- original em `score_raw` + a escala, e `score` fica normalizado pra 0-10
-- (nota 5 = 10). Assim o cálculo de promotor/detrator continua valendo e a CS
-- vê a nota como o aluno respondeu.

-- Resposta de quem não achamos na base (nome escrito diferente, ou pessoa que
-- não é aluno) também precisa ser guardada: fica sem aluno e a CS liga depois.
alter table nps_responses alter column student_id drop not null;

-- A coluna `source` tem uma regra que só aceita os valores antigos. Recria a
-- regra somando o que já existe na tabela + as origens novas, sem perder nada.
do $$
declare vals text;
begin
  select string_agg(distinct quote_literal(source), ', ') into vals
    from nps_responses where source is not null;
  vals := coalesce(vals || ', ', '') || quote_literal('pesquisa_2026_08') || ', ' ||
          quote_literal('primeiro_acesso') || ', ' || quote_literal('periodico') || ', ' ||
          quote_literal('planilha');
  execute 'alter table nps_responses drop constraint if exists nps_responses_source_check';
  execute 'alter table nps_responses add constraint nps_responses_source_check check (source is null or source in (' || vals || '))';
end $$;

alter table nps_responses add column if not exists scale            int;
alter table nps_responses add column if not exists score_raw        int;
alter table nps_responses add column if not exists respondent_name  text;
alter table nps_responses add column if not exists mentoria_informada text;
alter table nps_responses add column if not exists motivo           text;
alter table nps_responses add column if not exists melhorar         text;
alter table nps_responses add column if not exists feedback_geral   text;
alter table nps_responses add column if not exists instagram        text;

-- staging
drop table if exists pesquisa_nps;
create table pesquisa_nps (
  respondido_em timestamptz, nome text, chave text, mentoria text,
  nota int, motivo text, melhorar text, feedback_geral text, instagram text
);
insert into pesquisa_nps (respondido_em,nome,chave,mentoria,nota,motivo,melhorar,feedback_geral,instagram) values
  -- [LGPD] 152 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('2026-08-24 17:24:50-03'::timestamptz,'Exemplo fictício 10','Exemplo fictício 11','Mentoria Mãe',5,'Exemplo fictício 12','Exemplo fictício 13','Exemplo fictício 14','aluno012@exemplo.com'),
  ('2026-08-24 22:19:38-03'::timestamptz,'Exemplo fictício 15','Exemplo fictício 16','Ativação',3,'Exemplo fictício 17','Exemplo fictício 18','Exemplo fictício 19','Exemplo fictício 20'),
  ('2026-08-25 08:26:24-03'::timestamptz,'Exemplo fictício 21','Exemplo fictício 22','Ativação',5,'Exemplo fictício 23','Exemplo fictício 24','Exemplo fictício 25','Exemplo fictício 26');

-- casa com o aluno pelo nome (o formulário não pede e-mail)
alter table pesquisa_nps add column student_id uuid;
update pesquisa_nps p set student_id = s.id
  from students s
 where lower(regexp_replace(translate(s.full_name,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z ]', ' ', 'g')) ~ ('^' || p.chave || '$')
    or lower(regexp_replace(translate(s.full_name,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z ]', ' ', 'g')) = p.chave;

-- RELATÓRIO (não muda nada): quantas casaram
select count(*) as respostas,
       count(student_id) as casaram_com_aluno,
       count(*) - count(student_id) as sem_aluno_encontrado
  from pesquisa_nps;

select nome, mentoria, nota from pesquisa_nps where student_id is null order by nome;

-- IMPORTA (não duplica: apaga antes o que já tiver vindo desta pesquisa)
delete from nps_responses where source = 'pesquisa_2026_08';

insert into nps_responses (student_id, score, score_raw, scale, comment, source,
                           respondent_name, mentoria_informada, motivo, melhorar,
                           feedback_geral, instagram, created_at)
select p.student_id,
       round(p.nota * 2.0)::int,   -- 0-5 → 0-10
       p.nota, 5,
       coalesce(p.motivo, p.feedback_geral),
       'pesquisa_2026_08',
       p.nome, p.mentoria, p.motivo, p.melhorar, p.feedback_geral, p.instagram,
       p.respondido_em
  from pesquisa_nps p;

notify pgrst, 'reload schema';

select count(*) as importadas,
       round(avg(score_raw)::numeric, 2) as nota_media_0a5,
       count(*) filter (where score_raw = 5) as notas_5
  from nps_responses where source = 'pesquisa_2026_08';
