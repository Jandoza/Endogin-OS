-- v62: a carteira de cada CS e as pendências de 1:1 da planilha da Thaís.
--
-- Por que existe: no v60 eu atualizei o `cs_id` do ALUNO, mas quem manda na
-- visibilidade (e na contagem das Carteiras) é o `cs_id` de cada ENTREGA
-- (mentoria) — regra do v52. Entregas antigas continuaram com a CS anterior,
-- e por isso os números não batem com a planilha.
--
-- PARTE 1 e 2 são relatório. A 3 corrige. A 4 traz os 1:1.

-- ============================================================
-- PARTE 0 — o que a planilha diz
-- ============================================================
drop table if exists conferencia_cs;
create table conferencia_cs (cs text, na_planilha int);
insert into conferencia_cs (cs, na_planilha) values
  -- [LGPD] 7 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('Exemplo fictício 27', 98),
  ('Evelyn', 78),
  ('Horjana', 71);

-- ============================================================
-- PARTE 1 — RELATÓRIO: planilha x sistema, por CS
-- ============================================================
select c.cs,
       c.na_planilha,
       (select count(*) from students s join staff st on st.id = s.cs_id
         where st.full_name ilike c.cs || '%' and s.status not in ('inativo','cancelado'))       as por_cs_principal,
       (select count(distinct d.student_id) from deliveries d join staff st on st.id = d.cs_id
         where st.full_name ilike c.cs || '%' and d.status = 'ativo')                            as por_entrega_hoje
  from conferencia_cs c
 order by c.cs;

-- 1.2 alunos cuja entrega está com uma CS diferente da planilha
select s.full_name, b.name as mentoria,
       stf_hoje.full_name as cs_na_entrega_hoje,
       p.cs               as cs_na_planilha
  from planilha_thais p
  join students s   on lower(s.email) = p.email
  join branches b   on b.name = p.mentoria
  join deliveries d on d.student_id = s.id and d.branch_id = b.id
  left join staff stf_hoje on stf_hoje.id = d.cs_id
 where coalesce(stf_hoje.full_name, '') not ilike p.cs || '%'
 order by p.cs, s.full_name;

-- ============================================================
-- PARTE 2 — RELATÓRIO: entregas que a planilha não tem
-- (aluno em duas mentorias no sistema, uma só na planilha)
-- ============================================================
select s.full_name, b.name as mentoria_no_sistema, d.status,
       stf.full_name as cs_da_entrega, p.mentoria as mentoria_na_planilha
  from students s
  join deliveries d on d.student_id = s.id and d.status = 'ativo'
  join branches b   on b.id = d.branch_id
  left join staff stf on stf.id = d.cs_id
  left join planilha_thais p on p.email = lower(s.email)
 where p.mentoria is null or b.name <> p.mentoria
 order by s.full_name;

-- ============================================================
-- PARTE 3 — CORRIGE a CS de cada entrega conforme a planilha
-- ============================================================
update deliveries d
   set cs_id = st.id
  from planilha_thais p
  join students s on lower(s.email) = p.email
  join branches b on b.name = p.mentoria
  join staff st   on st.full_name ilike p.cs || '%' and st.is_active
 where d.student_id = s.id and d.branch_id = b.id
   and d.cs_id is distinct from st.id;

-- e o cs_id principal do aluno acompanha a entrega ativa dele
update students s set cs_id = d.cs_id
  from deliveries d
 where d.student_id = s.id and d.status = 'ativo' and d.cs_id is not null
   and s.cs_id is distinct from d.cs_id;

-- conferência depois de corrigir
select c.cs, c.na_planilha,
       (select count(distinct d.student_id) from deliveries d join staff st on st.id = d.cs_id
         where st.full_name ilike c.cs || '%' and d.status = 'ativo') as no_sistema_agora
  from conferencia_cs c order by c.cs;

-- ============================================================
-- PARTE 4 — sessões 1:1 que a planilha aponta (89 pendências)
-- ============================================================
alter table students add column if not exists one_on_one_type text;

drop table if exists pendencias_11;
create table pendencias_11 (nome text, cs text, tipo text, status11 text, data_11 text, obs text);
insert into pendencias_11 (nome,cs,tipo,status11,data_11,obs) values
  -- [LGPD] 89 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('Exemplo fictício 28','Cauane','Renovação','Pendente','RENOVOU','Exemplo fictício 29'),
  ('Exemplo fictício 30','Cauane','Renovação','Pendente','RENOVOU','Exemplo fictício 31'),
  ('Exemplo fictício 32','Cauane','Renovação','Pendente','RENOVOU','Exemplo fictício 33');

alter table pendencias_11 add column student_id uuid;
update pendencias_11 p set student_id = s.id
  from students s
 where lower(regexp_replace(translate(s.full_name,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z ]', ' ', 'g'))
     = lower(regexp_replace(translate(p.nome,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z ]', ' ', 'g'));

-- quem não casou pelo nome (a CS acerta na ficha)
select nome, cs, tipo, status11 from pendencias_11 where student_id is null order by nome;

update students s
   set one_on_one_status  = p.status11,
       one_on_one_type    = p.tipo,
       one_on_one_date    = coalesce(p.data_11, s.one_on_one_date),
       one_on_one_summary = coalesce(p.obs, s.one_on_one_summary)
  from pendencias_11 p
 where p.student_id = s.id;

notify pgrst, 'reload schema';

select count(*) filter (where one_on_one_status = 'Pendente')  as pendentes,
       count(*) filter (where one_on_one_status = 'Agendada')  as agendadas,
       count(*) filter (where one_on_one_status = 'Concluído') as concluidas
  from students;
