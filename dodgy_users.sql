
set define off

select d.username, u.account_status
from dba_users_with_defpwd d,
     dba_users u
where d.username = u.username
and   u.account_status NOT IN ('LOCKED', 'EXPIRED & LOCKED')
order by 1
/
