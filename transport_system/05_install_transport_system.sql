create or replace procedure clearing_house_commit.create_or_update_clearinghouse_system(
    p_only_drop boolean = false,
    p_dry_run boolean = false,
    p_only_update boolean = true
) as $$
begin

    set role clearinghouse_worker;

    call clearing_house.create_public_model(p_only_drop, p_dry_run, p_only_update);

    perform clearing_house_commit.generate_sead_tables();
    perform clearing_house_commit.generate_resolve_functions('public', p_dry_run);

    reset role;
    
end $$ language plpgsql;

call clearing_house_commit.create_or_update_clearinghouse_system(false, false, false);