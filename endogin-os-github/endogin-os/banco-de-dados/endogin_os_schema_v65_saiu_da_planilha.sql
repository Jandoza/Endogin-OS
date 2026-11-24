-- v65: fecha a diferença entre o sistema (490) e a planilha da Thaís (465).
--
-- De onde vem: comparei o painel dela de 01/09 com o de 22/09. Quem estava
-- como "Desativado", "Encerrado" ou "Inativo" no de 01/09 simplesmente saiu
-- do de 22/09 — ela tirou da planilha em vez de marcar. No nosso sistema
-- esses 16 continuaram contando como ativos.
--
-- Aqui eles viram inativos (o cadastro e o histórico ficam; só param de
-- contar e somem da carteira da CS).

drop table if exists saiu_da_planilha;
create table saiu_da_planilha (email text primary key, nome text, status_antigo text);
insert into saiu_da_planilha (email, nome, status_antigo) values
  -- [LGPD] 16 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('aluno013@exemplo.com','Exemplo fictício 34','Desativado'),
  ('aluno014@exemplo.com','Exemplo fictício 35','Desativado'),
  ('aluno015@exemplo.com','Exemplo fictício 36','Desativado')
on conflict (email) do nothing;

-- 1) o que vai mudar (confira antes)
select s.full_name, s.email, s.status as status_hoje, p.status_antigo,
       st.full_name as cs
  from saiu_da_planilha p
  join students s on lower(s.email) = p.email
  left join staff st on st.id = s.cs_id
 order by s.full_name;

-- 2) aplica
update students s
   set status = 'inativo', oculto_diretoria = true
  from saiu_da_planilha p
 where lower(s.email) = p.email and s.status not in ('inativo','cancelado');

update deliveries d set status = 'inativo'
  from saiu_da_planilha p join students s on lower(s.email) = p.email
 where d.student_id = s.id and d.status = 'ativo';

-- 3) conferência: tem que bater com a planilha (423 ativos)
select status, count(*) from students group by status order by 2 desc;

-- ============================================================
-- ATENÇÃO — estes 6 estavam ATIVOS no painel de 01/09 e sumiram do de 22/09
-- sem virar desativados. Não mexi neles. Pergunte à Thaís o que houve:
--   Aluno fictício | Ativação | aluno@exemplo.com
--   Aluno fictício | Endogin MÃE | aluno@exemplo.com
--   Aluno fictício | Endogin MÃE | aluno@exemplo.com
--   Aluno fictício | Endogin MÃE | aluno@exemplo.com
--   Aluno fictício | Ativação | aluno@exemplo.com
--   Aluno fictício | Endogin MÃE | aluno@exemplo.com
-- ============================================================
select s.full_name, s.email, s.status, st.full_name as cs
  from students s left join staff st on st.id = s.cs_id
 where lower(s.email) in ('aluno@exemplo.com', 'aluno016@exemplo.com', 'aluno017@exemplo.com', 'aluno018@exemplo.com', 'aluno019@exemplo.com', 'aluno020@exemplo.com');
