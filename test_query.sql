insert into admin_action_logs (
    account_id
    ,action
    ,target_type
    ,target_id
    ,recorded_changes
    ,created_at
    ,updated_at
)
values (
    1, 'create', 'DomainBlock', 78, '---\ndomain: fake.domain', now(), now()
);