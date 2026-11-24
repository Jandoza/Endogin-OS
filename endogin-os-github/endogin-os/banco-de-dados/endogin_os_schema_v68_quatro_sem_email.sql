-- v68: os 4 alunos que a planilha tem SEM e-mail.
--
-- Eles não existiam no sistema (por isso o casamento por nome do v67 não
-- achou ninguém). Aqui eles são criados. Sem e-mail eles não conseguem
-- entrar no Portal — quando a Thaís tiver o e-mail de cada um, é só
-- preencher na ficha.
--
-- Depois deste arquivo a conta fecha: 421 ativos · 12 em tratativa ·
-- 12 trancados · 18 encerraram · 463 pessoas.

drop table if exists novos_sem_email;
create table novos_sem_email (
  nome text, mentoria text, cs text, telefone text,
  entrada date, vencimento date, temperatura text, especialidade text
);
insert into novos_sem_email (nome,mentoria,cs,telefone,entrada,vencimento,temperatura,especialidade) values
  -- [LGPD] 4 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('Exemplo fictício 49','Mentores Masters','Horjana','11900000000','2025-04-28',null,'Quente',null),
  ('Exemplo fictício 50','Mentores Masters','Horjana','11900000000',null,null,'Quente',null),
  ('Exemplo fictício 51','Mentores Masters','Horjana','11900000000',null,null,'Quente',null);

-- cria quem ainda não existe (compara pelo nome, sem acento)
insert into students (full_name, email, phone, status, entry_date, renewal_date,
                      temperature, especialidade, cs_id, oculto_diretoria)
select n.nome,
       -- o cadastro exige um e-mail; este é provisório e aparece marcado na
       -- ficha até a Thaís colocar o de verdade
       'sem-email+' || lower(regexp_replace(translate(n.nome,
          'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
          'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z0-9]+', '.', 'g')) || '@pendente.endogin',
       n.telefone, 'ativo', n.entrada, n.vencimento,
       n.temperatura, n.especialidade,
       (select id from staff st where st.full_name ilike n.cs || '%' and st.is_active limit 1),
       false
  from novos_sem_email n
 where not exists (
   select 1 from students s
    where lower(regexp_replace(translate(s.full_name,
           'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
           'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g'))
        = lower(regexp_replace(translate(n.nome,
           'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
           'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g')));

-- garante que estão ativos e visíveis (caso já existissem inativados)
update students s set status = 'ativo', oculto_diretoria = false
  from novos_sem_email n
 where lower(regexp_replace(translate(s.full_name,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g'))
     = lower(regexp_replace(translate(n.nome,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g'));

-- mentoria e CS
insert into deliveries (student_id, branch_id, label, status, entry_date, renewal_date, cs_id)
select s.id, b.id, b.name, 'ativo', n.entrada, n.vencimento,
       (select id from staff st where st.full_name ilike n.cs || '%' and st.is_active limit 1)
  from novos_sem_email n
  join students s on lower(regexp_replace(translate(s.full_name,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g'))
     = lower(regexp_replace(translate(n.nome,
        'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
        'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Za-z ]',' ','g'))
  join branches b on b.name = n.mentoria
 where not exists (select 1 from deliveries d where d.student_id = s.id and d.branch_id = b.id);

-- CONFERÊNCIA — agora tem que ficar igual
select 'PLANILHA' as fonte, 421 as ativos, 12 as tratativa, 12 as trancados, 18 as encerraram, 463 as pessoas
union all
select 'SISTEMA',
       (select count(*) from students where status='ativo' and coalesce(renewal_status,'')<>'Resolvendo'),
       (select count(*) from students where status='ativo' and renewal_status='Resolvendo'),
       (select count(*) from students where status='trancado'),
       (select count(*) from students where status='cancelado'),
       (select count(*) from students where status in ('ativo','trancado','cancelado'));

-- quem está com e-mail provisório (a Thaís preenche o de verdade na ficha)
select full_name, email, status from students
 where email like 'aluno021@exemplo.com' order by full_name;
