drop database if exists studentmanagement;
create database studentmanagement;
use studentmanagement;

-- 1. table structure

create table students (
    studentid char(5) primary key,
    fullname varchar(50) not null,
    totaldebt decimal(10,2) default 0
);

create table subjects (
    subjectid char(5) primary key,
    subjectname varchar(50) not null,
    credits int check (credits > 0)
);

create table grades (
    studentid char(5),
    subjectid char(5),
    score decimal(4,2) check (score between 0 and 10),
    primary key (studentid, subjectid),
    constraint fk_grades_students foreign key (studentid) references students(studentid),
    constraint fk_grades_subjects foreign key (subjectid) references subjects(subjectid)
);

create table gradelog (
    logid int auto_increment primary key,
    studentid char(5),
    oldscore decimal(4,2),
    newscore decimal(4,2),
    changedate datetime default current_timestamp
);

-- 2. seed data

insert into students (studentid, fullname, totaldebt) values
('sv01', 'ho khanh linh', 5000000),
('sv03', 'tran thi khanh huyen', 0);

insert into subjects (subjectid, subjectname, credits) values
('sb01', 'co so du lieu', 3),
('sb02', 'lap trinh java', 4),
('sb03', 'lap trinh c', 3);

insert into grades (studentid, subjectid, score) values
('sv01', 'sb01', 8.5),
('sv03', 'sb02', 3.0);

-- Câu 1:
delimiter //
create trigger tg_checkscore
before insert on grades
for each row
begin
    if new.score < 0 then
        set new.score = 0;
    elseif new.score > 10 then
        set new.score = 10;
    end if;
end;
//
delimiter ;

-- Câu 2:
start transaction;
insert into students (studentid, fullname)
values ('sv02', 'ha bich ngoc');
update students
set totaldebt = 5000000
where studentid = 'sv02';
commit;


-- Câu 3:
delimiter //
create trigger tg_loggradeupdate
after update on grades
for each row
begin
    if old.score <> new.score then
        insert into gradelog (studentid, oldscore, newscore, changedate)
        values (old.studentid, old.score, new.score, now());
    end if;
end;
//
delimiter ;

-- Câu 4:
delimiter //
create procedure sp_paytuition()
begin
    declare v_totaldebt decimal(10,2);
    start transaction;
    update students
    set totaldebt = totaldebt - 2000000
    where studentid = 'sv01';
    select totaldebt into v_totaldebt
    from students
    where studentid = 'sv01';
    if v_totaldebt < 0 then
        rollback;
    else
        commit;
    end if;
end;
//
delimiter ;

-- cau 5: trigger chan sua diem da qua mon
delimiter //
create trigger tg_preventpassupdate
before update on grades
for each row
begin
    if old.score >= 4.0 then
        signal sqlstate '45000'
        set message_text = 'khong duoc phep sua diem khi sinh vien da qua mon';
    end if;
end;
//
delimiter ;

-- Câu 6:
delimiter //
create procedure sp_deletestudentgrade(
    in p_studentid char(5),
    in p_subjectid char(5)
)
begin
    declare v_oldscore decimal(4,2);
    start transaction;
    select score into v_oldscore
    from grades
    where studentid = p_studentid
      and subjectid = p_subjectid;
    insert into gradelog (studentid, oldscore, newscore, changedate)
    values (p_studentid, v_oldscore, null, now());
    delete from grades
    where studentid = p_studentid
      and subjectid = p_subjectid;
    if row_count() = 0 then
        rollback;
    else
        commit;
    end if;
end;
//
delimiter ;
