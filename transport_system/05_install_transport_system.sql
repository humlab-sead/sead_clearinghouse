
do $$
begin
    perform clearing_house_commit.generate_sead_tables();
    perform clearing_house_commit.generate_resolve_functions('public', false);
end $$ language plpgsql;
