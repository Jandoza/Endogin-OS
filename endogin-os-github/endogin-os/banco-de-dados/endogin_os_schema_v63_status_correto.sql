-- v63: acerta o STATUS de cada aluno com a planilha da Thaís.
--
-- O que eu errei no v60: a planilha marca "Ativo" também em quem está
-- TRANCADO (uma coluna à parte) e em quem está "Resolvendo". Eu joguei os
-- três no mesmo balaio 'ativo'. A conta certa da planilha é:
--   423 ativos · 12 trancados · 12 resolvendo · 18 encerraram = 465
--
-- Aqui: trancado vira status 'trancado'; resolvendo fica 'ativo' com a
-- situação anotada na renovação (é aluno ativo em tratativa); encerrou fica
-- 'cancelado' e escondido da diretoria.

drop table if exists status_planilha;
create table status_planilha (email text primary key, status_real text, rotulo text);
insert into status_planilha (email, status_real, rotulo) values
  -- [LGPD] 461 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('aluno006@exemplo.com','ativo','Ativo'),
  ('aluno008@exemplo.com','ativo','Ativo'),
  ('aluno010@exemplo.com','ativo','Ativo')
on conflict (email) do nothing;

-- ---------- 1) ANTES: como está hoje ----------
select status, count(*) from students group by status order by 2 desc;

-- ---------- 2) corrige ----------
update students s
   set status = p.status_real,
       renewal_status = case when p.rotulo = 'Resolvendo' then 'Resolvendo'
                             else s.renewal_status end,
       oculto_diretoria = (p.rotulo = 'Encerrou Mentoria')
  from status_planilha p
 where lower(s.email) = p.email
   and (s.status is distinct from p.status_real
        or s.oculto_diretoria is distinct from (p.rotulo = 'Encerrou Mentoria'));

-- entrega de quem trancou/encerrou não fica 'ativo'
update deliveries d set status = 'inativo'
  from students s
 where d.student_id = s.id and s.status in ('trancado','cancelado','inativo')
   and d.status = 'ativo';

-- ---------- 3) DEPOIS: tem que bater com a planilha ----------
select status, count(*) from students group by status order by 2 desc;

select
  (select count(*) from students where status = 'ativo')      as ativos,
  (select count(*) from students where status = 'trancado')   as trancados,
  (select count(*) from students where renewal_status = 'Resolvendo') as resolvendo,
  (select count(*) from students where status = 'cancelado')  as encerraram,
  (select count(*) from students)                             as total_cadastrado;

-- ---------- 4) quem o sistema tem e a planilha NÃO ----------
-- A Thaís precisa dizer o que fazer com cada um: pode ser aluno que entrou
-- pela Cademi depois, ou cadastro velho que deveria estar inativo.
select s.full_name, s.email, s.status, s.entry_date,
       st.full_name as cs, s.created_at::date as cadastrado_em
  from students s
  left join staff st on st.id = s.cs_id
 where not exists (select 1 from status_planilha p where p.email = lower(s.email))
 order by s.created_at desc nulls last;

-- ---------- 5) SÓ DEPOIS DE CONFERIR O 4 ----------
-- Tira da contagem de ativos quem não está na planilha da Thaís.
-- Descomente as duas linhas abaixo quando ela confirmar.
-- update students s set status = 'inativo'
--  where not exists (select 1 from status_planilha p where p.email = lower(s.email));
