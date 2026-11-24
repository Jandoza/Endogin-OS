-- v66: o sistema passa a ser um ESPELHO EXATO da planilha da Thaís
-- (arquivo "carteiras-cs-endogin", gerado em 22/09/2026 — 465 mentorados).
--
-- Rode este arquivo INTEIRO, de uma vez. Ele é seguro de repetir: roda
-- quantas vezes quiser e o resultado é sempre o mesmo.
--
-- O que ele faz, nesta ordem:
--   1. Carrega a planilha inteira numa tabela de trabalho.
--   2. Atualiza todo aluno que já existe (casando por e-mail).
--   3. Cria quem está na planilha e não existe aqui.
--   4. INATIVA quem existe aqui e NÃO está na planilha — é isso que faz o
--      total parar de ser maior do que a realidade.
--   5. Acerta a mentoria e a CS de cada um.
--   6. Esconde da Área de Mentores quem encerrou.
--
-- Contagem que a planilha manda (é o que tem que aparecer no fim):
--   ativos de fato: 423 · em tratativa ("Resolvendo"): 12
--   trancados: 12 · encerraram: 18 · TOTAL: 465

-- ============================================================
-- 1. a planilha
-- ============================================================
drop table if exists espelho_planilha;
create table espelho_planilha (
  nome text, email text, telefone text, mentoria text, cs text,
  status text, oculto boolean, rotulo text, trancado boolean,
  entrada date, vencimento date, temperatura text, renovacao text,
  obs text, aniversario date, instagram text, especialidade text, cidade_uf text
);
insert into espelho_planilha
  (nome,email,telefone,mentoria,cs,status,oculto,rotulo,trancado,
   entrada,vencimento,temperatura,renovacao,obs,aniversario,instagram,especialidade,cidade_uf)
values
  -- [LGPD] 465 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('Exemplo fictício 37','aluno006@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 38','ativo',false,'Ativo',false,'2025-12-13','2026-12-13','Frio',null,null,'1985-11-20','aluno007@exemplo.com','Nutróloga','Exemplo fictício 39'),
  ('Exemplo fictício 40','aluno008@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 41','ativo',false,'Ativo',false,'2025-10-28','2026-10-28','Morno',null,null,'1987-09-27','aluno009@exemplo.com','cardiologista','Exemplo fictício 42'),
  ('Exemplo fictício 43','aluno010@exemplo.com','11900000000','Start Caio e Jordana','Exemplo fictício 44','ativo',false,'Ativo',false,'2025-12-03','2026-12-03','Morno',null,null,'1992-11-13','aluno011@exemplo.com','Endocrinologista','Exemplo fictício 45');

-- garante as colunas usadas abaixo
alter table students add column if not exists especialidade text;
alter table students add column if not exists cidade_uf text;
alter table students add column if not exists oculto_diretoria boolean not null default false;

-- ============================================================
-- 2. atualiza quem já existe
-- ============================================================
update students s set
  full_name        = p.nome,
  phone            = coalesce(p.telefone, s.phone),
  status           = p.status,
  oculto_diretoria = p.oculto,
  entry_date       = coalesce(p.entrada, s.entry_date),
  renewal_date     = coalesce(p.vencimento, s.renewal_date),
  temperature      = coalesce(p.temperatura, s.temperature),
  renewal_status   = case when p.rotulo = 'Resolvendo' then 'Resolvendo'
                          else coalesce(p.renovacao, s.renewal_status) end,
  notes            = coalesce(p.obs, s.notes),
  birth_date       = coalesce(p.aniversario, s.birth_date),
  instagram        = coalesce(p.instagram, s.instagram),
  especialidade    = coalesce(p.especialidade, s.especialidade),
  cidade_uf        = coalesce(p.cidade_uf, s.cidade_uf)
from espelho_planilha p
where lower(s.email) = p.email and p.email is not null;

-- ============================================================
-- 3. cria quem falta
-- ============================================================
insert into students (full_name, email, phone, status, oculto_diretoria, entry_date,
                      renewal_date, temperature, renewal_status, notes, birth_date,
                      instagram, especialidade, cidade_uf, cs_id)
select p.nome, p.email, p.telefone, p.status, p.oculto, p.entrada, p.vencimento,
       p.temperatura,
       case when p.rotulo = 'Resolvendo' then 'Resolvendo' else p.renovacao end,
       p.obs, p.aniversario, p.instagram, p.especialidade, p.cidade_uf,
       (select id from staff st where st.full_name ilike p.cs || '%' and st.is_active limit 1)
  from espelho_planilha p
 where p.email is not null
   and not exists (select 1 from students s where lower(s.email) = p.email);

-- ============================================================
-- 4. quem não está na planilha sai da conta
--    (o cadastro e o histórico ficam; só não conta mais como aluno)
-- ============================================================
update students s
   set status = 'inativo', oculto_diretoria = true
 where not exists (select 1 from espelho_planilha p where p.email = lower(s.email))
   and s.status <> 'inativo';

-- ============================================================
-- 5. mentoria e CS de cada um, conforme a planilha
-- ============================================================
-- a entrega da mentoria que a planilha aponta
insert into deliveries (student_id, branch_id, label, status, entry_date, renewal_date, cs_id)
select s.id, b.id, b.name,
       case when p.status = 'ativo' then 'ativo' else 'inativo' end,
       p.entrada, p.vencimento,
       (select id from staff st where st.full_name ilike p.cs || '%' and st.is_active limit 1)
  from espelho_planilha p
  join students s on lower(s.email) = p.email
  join branches b on b.name = p.mentoria
 where not exists (select 1 from deliveries d where d.student_id = s.id and d.branch_id = b.id);

update deliveries d set
  status       = case when p.status = 'ativo' then 'ativo' else 'inativo' end,
  entry_date   = coalesce(p.entrada, d.entry_date),
  renewal_date = coalesce(p.vencimento, d.renewal_date),
  cs_id        = coalesce((select id from staff st where st.full_name ilike p.cs || '%' and st.is_active limit 1), d.cs_id)
  from espelho_planilha p
  join students s on lower(s.email) = p.email
  join branches b on b.name = p.mentoria
 where d.student_id = s.id and d.branch_id = b.id;

-- entrega de quem não está mais ativo não fica ativa
update deliveries d set status = 'inativo'
  from students s
 where d.student_id = s.id and s.status <> 'ativo' and d.status = 'ativo';

-- o cadastro do aluno aponta pra CS da entrega ativa dele
update students s set cs_id = d.cs_id
  from deliveries d
 where d.student_id = s.id and d.status = 'ativo' and d.cs_id is not null
   and s.cs_id is distinct from d.cs_id;

-- ============================================================
-- 6. CONFERÊNCIA — tem que bater com a planilha
-- ============================================================
select 'PLANILHA' as fonte, 423 as ativos, 12 as resolvendo, 12 as trancados, 18 as encerraram, 465 as total
union all
select 'SISTEMA',
       (select count(*) from students where status = 'ativo' and coalesce(renewal_status,'') <> 'Resolvendo'),
       (select count(*) from students where status = 'ativo' and renewal_status = 'Resolvendo'),
       (select count(*) from students where status = 'trancado'),
       (select count(*) from students where status = 'cancelado'),
       (select count(*) from students where status in ('ativo','trancado','cancelado'));

-- por CS (só ativos) — tem que bater com a carteira de cada uma
select st.full_name as cs, count(distinct d.student_id) as alunos
  from deliveries d
  join staff st on st.id = d.cs_id
 where d.status = 'ativo'
 group by st.full_name order by 2 desc;

-- quem está escondido da Área de Mentores
select count(*) as ocultos_da_diretoria from students where oculto_diretoria;
