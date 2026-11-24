-- v60: conferência e atualização da base com a carteira da Thaís
-- (arquivo "carteiras-cs-endogin", gerado em 22/09/2026 — 465 mentorados).
--
-- RODE POR PARTES, na ordem. A PARTE 3 é só relatório: nada muda no banco.
-- Só rode a PARTE 4 depois de olhar o relatório e concordar com ele.

-- ============================================================
-- PARTE 1 — colunas que faltavam no nosso cadastro
-- ============================================================
alter table students add column if not exists especialidade text;
alter table students add column if not exists cidade_uf text;
-- quem encerrou a mentoria continua visível pra CS/Thaís, mas some das telas
-- da diretoria (pedido do Luiz)
alter table students add column if not exists oculto_diretoria boolean not null default false;

-- ============================================================
-- PARTE 2 — a planilha vira uma tabela temporária de conferência
-- ============================================================
drop table if exists planilha_thais;
create table planilha_thais (
  nome text, email text, telefone text, mentoria text, cs text,
  status text, status_planilha text, entrada date, vencimento date,
  temperatura text, renovacao text, obs text, aniversario date,
  instagram text, especialidade text, cidade_uf text, respondeu_icp boolean
);

insert into planilha_thais
  (nome,email,telefone,mentoria,cs,status,status_planilha,entrada,vencimento,
   temperatura,renovacao,obs,aniversario,instagram,especialidade,cidade_uf,respondeu_icp)
values
  -- [LGPD] 465 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('Exemplo fictício 1','aluno006@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 2','ativo','Ativo','2025-12-13','2026-12-13','Frio',null,null,'1985-11-20','aluno007@exemplo.com','Nutróloga','Exemplo fictício 3',false),
  ('Exemplo fictício 4','aluno008@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 5','ativo','Ativo','2025-10-28','2026-10-28','Morno',null,null,'1987-09-27','aluno009@exemplo.com','cardiologista','Exemplo fictício 6',true),
  ('Exemplo fictício 7','aluno010@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 8','ativo','Ativo','2025-12-03','2026-12-03','Morno',null,null,'1992-11-13','aluno011@exemplo.com','Endocrinologista','Exemplo fictício 9',false);

-- ============================================================
-- PARTE 3 — RELATÓRIO (não muda nada). Rode uma consulta por vez.
-- ============================================================

-- 3.1 resumo geral
select
  (select count(*) from planilha_thais)                                          as na_planilha,
  (select count(*) from students)                                                as no_sistema,
  (select count(*) from planilha_thais p
     join students s on lower(s.email) = p.email)                                as casaram_por_email,
  (select count(*) from planilha_thais p
    where p.email is not null
      and not exists (select 1 from students s where lower(s.email) = p.email))  as so_na_planilha,
  (select count(*) from students s
    where s.status not in ('inativo','cancelado')
      and not exists (select 1 from planilha_thais p where p.email = lower(s.email))) as so_no_sistema;

-- 3.2 quem está na planilha e NÃO existe no sistema (vai ser criado)
select p.nome, p.email, p.mentoria, p.cs, p.status_planilha, p.entrada, p.vencimento
  from planilha_thais p
 where p.email is not null
   and not exists (select 1 from students s where lower(s.email) = p.email)
 order by p.mentoria, p.nome;

-- 3.3 quem está ativo no sistema e NÃO está na planilha (conferir com a Thaís)
select s.full_name, s.email, s.status, st.full_name as cs_atual
  from students s left join staff st on st.id = s.cs_id
 where s.status not in ('inativo','cancelado')
   and not exists (select 1 from planilha_thais p where p.email = lower(s.email))
 order by s.full_name;

-- 3.4 diferenças campo a campo (o que a PARTE 4 vai corrigir)
select p.nome, p.email,
       case when s.full_name is distinct from p.nome then s.full_name || ' → ' || p.nome end as nome_muda,
       case when s.entry_date is distinct from p.entrada then coalesce(s.entry_date::text,'—') || ' → ' || p.entrada::text end as entrada_muda,
       case when s.renewal_date is distinct from p.vencimento then coalesce(s.renewal_date::text,'—') || ' → ' || p.vencimento::text end as vencimento_muda,
       case when s.status is distinct from p.status then s.status || ' → ' || p.status end as status_muda,
       case when coalesce(s.temperature,'') is distinct from coalesce(p.temperatura,'') then coalesce(s.temperature,'—') || ' → ' || coalesce(p.temperatura,'—') end as temperatura_muda,
       case when st.full_name is distinct from p.cs then coalesce(st.full_name,'—') || ' → ' || p.cs end as cs_muda
  from planilha_thais p
  join students s on lower(s.email) = p.email
  left join staff st on st.id = s.cs_id
 where s.full_name is distinct from p.nome
    or s.entry_date is distinct from p.entrada
    or s.renewal_date is distinct from p.vencimento
    or s.status is distinct from p.status
    or coalesce(s.temperature,'') is distinct from coalesce(p.temperatura,'')
 order by p.nome;

-- 3.5 aniversários que a planilha tem sem o ano (ex: "15/08") ficaram de fora:
-- o sistema precisa da data completa. Peça esses à Thaís.
select s.full_name, s.email
  from planilha_thais p join students s on lower(s.email) = p.email
 where p.aniversario is null and s.birth_date is null
 order by s.full_name;

-- 3.6 quem vai sumir das telas da diretoria (encerrou a mentoria)
select p.nome, p.email, p.mentoria, p.cs
  from planilha_thais p
 where p.status_planilha = 'Encerrou Mentoria'
 order by p.mentoria, p.nome;

-- ============================================================
-- PARTE 4 — APLICAR. Só depois de conferir a PARTE 3.
-- ============================================================

-- 4.1 atualiza quem já existe (casando por e-mail)
update students s set
  full_name      = coalesce(p.nome, s.full_name),
  phone          = coalesce(p.telefone, s.phone),
  entry_date     = coalesce(p.entrada, s.entry_date),
  renewal_date   = coalesce(p.vencimento, s.renewal_date),
  status         = p.status,
  temperature    = coalesce(p.temperatura, s.temperature),
  renewal_status = coalesce(p.renovacao, s.renewal_status),
  notes          = coalesce(nullif(p.obs,''), s.notes),
  birth_date     = coalesce(p.aniversario, s.birth_date),
  instagram      = coalesce(p.instagram, s.instagram),
  especialidade  = coalesce(p.especialidade, s.especialidade),
  cidade_uf      = coalesce(p.cidade_uf, s.cidade_uf),
  respondeu_icp  = p.respondeu_icp,
  oculto_diretoria = (p.status_planilha = 'Encerrou Mentoria')
from planilha_thais p
where lower(s.email) = p.email;

-- 4.2 cria quem está na planilha e não existe
insert into students (full_name, email, phone, status, entry_date, renewal_date,
                      temperature, renewal_status, notes, birth_date, instagram,
                      especialidade, cidade_uf, respondeu_icp, oculto_diretoria, cs_id)
select p.nome, p.email, p.telefone, p.status, p.entrada, p.vencimento,
       p.temperatura, p.renovacao, nullif(p.obs,''), p.aniversario, p.instagram,
       p.especialidade, p.cidade_uf, p.respondeu_icp,
       (p.status_planilha = 'Encerrou Mentoria'),
       (select id from staff st where st.full_name ilike p.cs || '%' and st.is_active limit 1)
  from planilha_thais p
 where p.email is not null
   and not exists (select 1 from students s where lower(s.email) = p.email);

-- 4.3 CS responsável conforme a planilha
update students s
   set cs_id = st.id
  from planilha_thais p
  join staff st on st.full_name ilike p.cs || '%' and st.is_active
 where lower(s.email) = p.email;

-- 4.4 mentoria (entrega) conforme a planilha
insert into deliveries (student_id, branch_id, label, status, entry_date, renewal_date, cs_id)
select s.id, b.id, b.name, 'ativo', p.entrada, p.vencimento, s.cs_id
  from planilha_thais p
  join students s on lower(s.email) = p.email
  join branches b on b.name = p.mentoria
 where not exists (select 1 from deliveries d where d.student_id = s.id and d.branch_id = b.id);

update deliveries d set entry_date = p.entrada, renewal_date = p.vencimento
  from planilha_thais p
  join students s on lower(s.email) = p.email
  join branches b on b.name = p.mentoria
 where d.student_id = s.id and d.branch_id = b.id;

-- 4.5 quem encerrou: entregas desativadas
update deliveries d set status = 'inativo'
  from planilha_thais p join students s on lower(s.email) = p.email
 where d.student_id = s.id and p.status_planilha = 'Encerrou Mentoria';

-- ============================================================
-- PARTE 5 — a diretoria deixa de ver quem encerrou
-- ============================================================
drop policy if exists students_select_diretoria on students;
create policy students_select_diretoria on students
  for select to authenticated
  using (is_current_staff_diretoria() and coalesce(oculto_diretoria, false) = false);

notify pgrst, 'reload schema';

-- conferência final
select
  (select count(*) from students)                                as total,
  (select count(*) from students where oculto_diretoria)         as ocultos_da_diretoria,
  (select count(*) from students where status = 'ativo')         as ativos;
