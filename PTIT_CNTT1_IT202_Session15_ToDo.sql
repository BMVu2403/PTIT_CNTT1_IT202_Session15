drop database if exists mini_social_network;
create database mini_social_network;
use mini_social_network;

create table users (
    user_id int auto_increment primary key,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    created_at datetime default current_timestamp
);

create table posts (
    post_id int auto_increment primary key,
    user_id int,
    content text not null,
    like_count int default 0,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table comments (
    comment_id int auto_increment primary key,
    post_id int,
    user_id int,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (post_id) references posts(post_id) on delete cascade,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table likes (
    user_id int,
    post_id int,
    created_at datetime default current_timestamp,
    primary key (user_id, post_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (post_id) references posts(post_id) on delete cascade
);

create table friends (
    user_id int,
    friend_id int,
    status varchar(20) default 'pending',
    created_at datetime default current_timestamp,
    primary key (user_id, friend_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (friend_id) references users(user_id) on delete cascade,
    check (status in ('pending','accepted'))
);

create table user_log (
    log_id int auto_increment primary key,
    user_id int,
    action varchar(100),
    log_time datetime default current_timestamp
);

create table post_log (
    log_id int auto_increment primary key,
    post_id int,
    action varchar(100),
    log_time datetime default current_timestamp
);

create table like_log (
    log_id int auto_increment primary key,
    user_id int,
    post_id int,
    action varchar(50),
    log_time datetime default current_timestamp
);

create table friend_log (
    log_id int auto_increment primary key,
    user_id int,
    friend_id int,
    action varchar(100),
    log_time datetime default current_timestamp
);

delimiter //

create procedure sp_register_user(
    in p_username varchar(50),
    in p_password varchar(255),
    in p_email varchar(100)
)
begin
    if exists (select 1 from users where username=p_username) then
        signal sqlstate '45000' set message_text='username exists';
    end if;
    if exists (select 1 from users where email=p_email) then
        signal sqlstate '45000' set message_text='email exists';
    end if;
    insert into users(username,password,email)
    values(p_username,p_password,p_email);
end//

create trigger trg_after_register
after insert on users
for each row
begin
    insert into user_log(user_id,action)
    values(new.user_id,'register');
end//

create procedure sp_create_post(
    in p_user_id int,
    in p_content text
)
begin
    if p_content is null or trim(p_content)='' then
        signal sqlstate '45000' set message_text='empty content';
    end if;
    insert into posts(user_id,content)
    values(p_user_id,p_content);
end//

create trigger trg_after_post
after insert on posts
for each row
begin
    insert into post_log(post_id,action)
    values(new.post_id,'create_post');
end//

create trigger trg_like
after insert on likes
for each row
begin
    update posts set like_count=like_count+1
    where post_id=new.post_id;
    insert into like_log(user_id,post_id,action)
    values(new.user_id,new.post_id,'like');
end//

create trigger trg_unlike
after delete on likes
for each row
begin
    update posts set like_count=like_count-1
    where post_id=old.post_id;
    insert into like_log(user_id,post_id,action)
    values(old.user_id,old.post_id,'unlike');
end//

create procedure sp_send_friend_request(
    in p_sender int,
    in p_receiver int
)
begin
    if p_sender=p_receiver then
        signal sqlstate '45000' set message_text='invalid';
    end if;
    if exists (
        select 1 from friends
        where user_id=p_sender and friend_id=p_receiver
    ) then
        signal sqlstate '45000' set message_text='exists';
    end if;
    insert into friends(user_id,friend_id)
    values(p_sender,p_receiver);
end//

create trigger trg_friend_request
after insert on friends
for each row
begin
    insert into friend_log(user_id,friend_id,action)
    values(new.user_id,new.friend_id,'send_request');
end//

create procedure sp_accept_friend(
    in p_user_id int,
    in p_friend_id int
)
begin
    start transaction;
    update friends
    set status='accepted'
    where user_id=p_user_id
      and friend_id=p_friend_id
      and status='pending';
    insert ignore into friends(user_id,friend_id,status)
    values(p_friend_id,p_user_id,'accepted');
    commit;
end//

create procedure sp_remove_friend(
    in p_u1 int,
    in p_u2 int
)
begin
    start transaction;
    delete from friends where user_id=p_u1 and friend_id=p_u2;
    delete from friends where user_id=p_u2 and friend_id=p_u1;
    commit;
end//

create procedure sp_delete_post(
    in p_post_id int,
    in p_user_id int
)
begin
    start transaction;
    if not exists (
        select 1 from posts
        where post_id=p_post_id and user_id=p_user_id
    ) then
        signal sqlstate '45000' set message_text='not owner';
    end if;
    delete from posts where post_id=p_post_id;
    commit;
end//

create procedure sp_delete_user(
    in p_user_id int
)
begin
    start transaction;
    delete from users where user_id=p_user_id;
    commit;
end//

delimiter ;

call sp_register_user('alice','123','alice@gmail.com');
call sp_register_user('bob','123','bob@gmail.com');
call sp_register_user('charlie','123','charlie@gmail.com');

call sp_create_post(1,'hello');
call sp_create_post(1,'second post');
call sp_create_post(2,'bob post');

insert into likes values(2,1,now());
insert into likes values(3,1,now());
delete from likes where user_id=2 and post_id=1;

call sp_send_friend_request(1,2);
call sp_accept_friend(1,2);

select * from users;
select * from posts;
select * from likes;
select * from friends;
select * from user_log;
select * from post_log;
select * from like_log;
select * from friend_log;
