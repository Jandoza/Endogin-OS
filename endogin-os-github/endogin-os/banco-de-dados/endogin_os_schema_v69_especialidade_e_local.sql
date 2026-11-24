-- v69: especialidade, cidade e estado de cada mentorado.
--
-- A planilha escreve a especialidade de 80 jeitos diferentes ("Nutrologia",
-- "Nutrologo", "Nutróloga", "Nutologia"...). Aqui elas viram 22 nomes
-- padronizados — sem isso nenhum gráfico faz sentido. O texto original fica
-- guardado em `especialidade_original`, pra nada se perder.
--
-- A cidade vem como "Vitória/ES": separo em cidade e estado (UF), que é o
-- que permite agrupar por região.

alter table students add column if not exists especialidade text;
alter table students add column if not exists especialidade_original text;
alter table students add column if not exists cidade text;
alter table students add column if not exists uf text;
alter table students add column if not exists cidade_uf text;

drop table if exists dados_extras;
create table dados_extras (
  email text primary key, especialidade text, cidade text, uf text,
  especialidade_original text, evento_mentalidade text, levara_conjuge text
);
insert into dados_extras (email,especialidade,cidade,uf,especialidade_original,evento_mentalidade,levara_conjuge) values
  -- [LGPD] 461 linhas com dados reais de alunos foram removidas;
  -- abaixo ficam só 3 linhas FICTÍCIAS de exemplo, no mesmo formato.
  ('aluno006@exemplo.com','Nutrologia','Maceió','AL','Nutróloga',null,null),
  ('aluno008@exemplo.com','Cardiologia','Exemplo fictício 52','RS','cardiologista',null,null),
  ('aluno010@exemplo.com','Endocrinologia','Brasilia','DF','Endocrinologista',null,null)
on conflict (email) do nothing;

update students s set
  especialidade          = coalesce(p.especialidade, s.especialidade),
  especialidade_original = coalesce(p.especialidade_original, s.especialidade_original),
  cidade                 = coalesce(p.cidade, s.cidade),
  uf                     = coalesce(p.uf, s.uf),
  cidade_uf              = coalesce(nullif(trim(coalesce(p.cidade,'') || case when p.uf is not null then '/' || p.uf else '' end), ''), s.cidade_uf)
from dados_extras p
where lower(s.email) = p.email;

create index if not exists students_uf_idx on students (uf);
create index if not exists students_esp_idx on students (especialidade);

notify pgrst, 'reload schema';

-- conferência
select count(*) filter (where especialidade is not null) as com_especialidade,
       count(*) filter (where uf is not null)            as com_estado,
       count(distinct especialidade)                     as especialidades,
       count(distinct uf)                                as estados
  from students where status in ('ativo','trancado');

select especialidade, count(*) from students
 where status = 'ativo' and especialidade is not null
 group by 1 order by 2 desc;

select uf, count(*) from students
 where status = 'ativo' and uf is not null
 group by 1 order by 2 desc;
