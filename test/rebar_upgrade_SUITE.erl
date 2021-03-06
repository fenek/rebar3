-module(rebar_upgrade_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).

all() -> [{group, git}, {group, pkg}, novsn_pkg].

groups() ->
    [{all, [], [top_a, top_b, top_c, top_d1, top_d2, top_e,
                pair_a, pair_b, pair_ab, pair_c, pair_all,
                triplet_a, triplet_b, triplet_c,
                tree_a, tree_b, tree_c, tree_c2, tree_ac, tree_all,
                delete_d, promote, stable_lock, fwd_lock]},
     {git, [], [{group, all}]},
     {pkg, [], [{group, all}]}].

init_per_suite(Config) ->
    application:start(meck),
    Config.

end_per_suite(_Config) ->
    application:stop(meck).

init_per_group(git, Config) ->
    [{deps_type, git} | Config];
init_per_group(pkg, Config) ->
    [{deps_type, pkg} | Config];
init_per_group(_, Config) ->
    Config.

end_per_group(_, Config) ->
    Config.

init_per_testcase(novsn_pkg, Config0) ->
    Config = rebar_test_utils:init_rebar_state(Config0, "novsn_pkg_"),
    AppDir = ?config(apps, Config),
    RebarConf = rebar_test_utils:create_config(AppDir, [{deps, [fakeapp]}]),

    Deps = [{{<<"fakeapp">>, <<"1.0.0">>}, []}],
    UpDeps = [{{<<"fakeapp">>, <<"1.1.0">>}, []}],
    Upgrades = ["fakeapp"],

    [{rebarconfig, RebarConf},
     {mock, fun() ->
        catch mock_pkg_resource:unmock(),
        mock_pkg_resource:mock([{pkgdeps, Deps}, {upgrade, []}])
      end},
     {mock_update, fun() ->
        catch mock_pkg_resource:unmock(),
        mock_pkg_resource:mock([{pkgdeps, UpDeps}, {upgrade, Upgrades}])
      end},
     {expected, {ok, [{dep, "fakeapp", "1.1.0"}, {lock, "fakeapp", "1.1.0"}]}}
     | Config];
init_per_testcase(Case, Config) ->
    DepsType = ?config(deps_type, Config),
    {Deps, UpDeps, ToUp, Expectations} = upgrades(Case),
    Expanded = rebar_test_utils:expand_deps(DepsType, Deps),
    UpExpanded = rebar_test_utils:expand_deps(DepsType, UpDeps),
    [{expected, normalize_unlocks(Expectations)},
     {mock, fun() -> mock_deps(DepsType, Expanded, []) end},
     {mock_update, fun() -> mock_deps(DepsType, Expanded, UpExpanded, ToUp) end}
     | setup_project(Case, Config, Expanded, UpExpanded)].

end_per_testcase(_, Config) ->
    meck:unload(),
    Config.

setup_project(Case, Config0, Deps, UpDeps) ->
    DepsType = ?config(deps_type, Config0),
    Config = rebar_test_utils:init_rebar_state(
            Config0,
            atom_to_list(Case)++"_"++atom_to_list(DepsType)++"_"
    ),
    AppDir = ?config(apps, Config),
    rebar_test_utils:create_app(AppDir, "Root", "0.0.0", [kernel, stdlib]),
    TopDeps = rebar_test_utils:top_level_deps(Deps),
    RebarConf = rebar_test_utils:create_config(AppDir, [{deps, TopDeps}]),
    [{rebarconfig, RebarConf},
     {next_top_deps, rebar_test_utils:top_level_deps(UpDeps)} | Config].


upgrades(top_a) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"A", [{"A","1"}, "B", "C", {"D","3"}]}};
upgrades(top_b) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"B", {error, {rebar_prv_upgrade, {transitive_dependency, <<"B">>}}}}};
upgrades(top_c) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"C", {error, {rebar_prv_upgrade, {transitive_dependency, <<"C">>}}}}};
upgrades(top_d1) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"D", {error, {rebar_prv_upgrade, {transitive_dependency, <<"D">>}}}}};
upgrades(top_d2) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"D", {error, {rebar_prv_upgrade, {transitive_dependency, <<"D">>}}}}};
upgrades(top_e) ->
     %% Original tree
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Updated tree
     [{"A", "1", [{"B", [{"D", "3", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     %% Modified apps, gobally
     ["A","B","D"],
     %% upgrade vs. new tree
     {"E", {error, {rebar_prv_upgrade, {unknown_dependency, <<"E">>}}}}};
upgrades(pair_a) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     {"A", [{"A","2"},{"C","2"},{"B","1"},{"D","1"}]}};
upgrades(pair_b) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     {"B", [{"A","1"},{"C","1"},{"B","2"},{"D","2"}]}};
upgrades(pair_ab) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     {"A,B", [{"A","2"},{"C","2"},{"B","2"},{"D","2"}]}};
upgrades(pair_c) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     {"C", {error, {rebar_prv_upgrade, {transitive_dependency, <<"C">>}}}}};
upgrades(pair_all) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     {"", [{"A","2"},{"C","2"},{"B","2"},{"D","2"}]}};
upgrades(triplet_a) ->
    {[{"A", "1", [{"D",[]},
                  {"E","3",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "0", [{"H","3",[]},
                  {"I",[]}]}],
     [{"A", "1", [{"D",[]},
                  {"E","2",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "1", [{"H","4",[]},
                  {"I",[]}]}],
     ["A","C","E","H"],
     {"A", [{"A","1"}, "D", {"E","2"},
            {"B","1"}, {"F","1"}, "G",
            {"C","0"}, {"H","3"}, "I"]}};
upgrades(triplet_b) ->
    {[{"A", "1", [{"D",[]},
                  {"E","3",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "0", [{"H","3",[]},
                  {"I",[]}]}],
     [{"A", "2", [{"D",[]},
                  {"E","2",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "1", [{"H","4",[]},
                  {"I",[]}]}],
     ["A","C","E","H"],
     {"B", [{"A","1"}, "D", {"E","3"},
            {"B","1"}, {"F","1"}, "G",
            {"C","0"}, {"H","3"}, "I"]}};
upgrades(triplet_c) ->
    {[{"A", "1", [{"D",[]},
                  {"E","3",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "0", [{"H","3",[]},
                  {"I",[]}]}],
     [{"A", "2", [{"D",[]},
                  {"E","2",[]}]},
      {"B", "1", [{"F","1",[]},
                  {"G",[]}]},
      {"C", "1", [{"H","4",[]},
                  {"I",[]}]}],
     ["A","C","E","H"],
     {"C", [{"A","1"}, "D", {"E","3"},
            {"B","1"}, {"F","1"}, "G",
            {"C","1"}, {"H","4"}, "I"]}};
upgrades(tree_a) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "2", [{"H",[]}]}
     ],
     ["C"],
     {"A", [{"A","1"}, "D", "J", "E",
            {"B","1"}, "F", "G",
            {"C","1"}, "H", {"I","2"}]}};
upgrades(tree_b) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "2", [{"H",[]}]}
     ],
     ["C"],
     {"B", [{"A","1"}, "D", "J", "E",
            {"B","1"}, "F", "G",
            {"C","1"}, "H", {"I","2"}]}};
upgrades(tree_c) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]}]}
     ],
     ["C","I"],
     {"C", [{"A","1"}, "D", "J", "E", {"I","1"},
            {"B","1"}, "F", "G",
            {"C","1"}, "H"]}};
upgrades(tree_c2) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[{"K",[]}]},
                  {"I","2",[]}]}
     ],
     ["C", "H"],
     {"C", [{"A","1"}, "D", "J", "E",
            {"B","1"}, "F", "G",
            {"C","1"}, "H", {"I", "2"}, "K"]}};
upgrades(tree_ac) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]}]}
     ],
     ["C","I"],
     {"C, A", [{"A","1"}, "D", "J", "E", {"I","1"},
               {"B","1"}, "F", "G",
               {"C","1"}, "H"]}};
upgrades(tree_all) ->
    {[{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]},
                  {"I","2",[]}]}
     ],
     [{"A", "1", [{"D",[{"J",[]}]},
                  {"E",[{"I","1",[]}]}]},
      {"B", "1", [{"F",[]},
                  {"G",[]}]},
      {"C", "1", [{"H",[]}]}
     ],
     ["C","I"],
     {"", [{"A","1"}, "D", "J", "E", {"I","1"},
           {"B","1"}, "F", "G",
           {"C","1"}, "H"]}};
upgrades(delete_d) ->
    {[{"A", "1", [{"B", [{"D", "1", []}]},
                  {"C", [{"D", "2", []}]}]}
     ],
     [{"A", "2", [{"B", []},
                  {"C", []}]}
     ],
     ["A","B", "C"],
     %% upgrade vs. new tree
     {"", [{"A","2"}, "B", "C"]}};
upgrades(promote) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]},
      {"C", "3", []}
     ],
     ["A","B","C","D"],
     {"C", [{"A","1"},{"C","3"},{"B","1"},{"D","1"}]}};
upgrades(stable_lock) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ], % lock after this
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     [],
     %% Run a regular lock and no app should be upgraded
     {"any", [{"A","1"},{"C","1"},{"B","1"},{"D","1"}]}};
upgrades(fwd_lock) ->
    {[{"A", "1", [{"C", "1", []}]},
      {"B", "1", [{"D", "1", []}]}
     ],
     [{"A", "2", [{"C", "2", []}]},
      {"B", "2", [{"D", "2", []}]}
     ],
     ["A","B","C","D"],
     %% For this one, we should build, rewrite the lock
     %% file to include the result post-upgrade, and then
     %% run a regular lock to see that the lock file is respected
     %% in deps.
     {"any", [{"A","2"},{"C","2"},{"B","2"},{"D","2"}]}}.

%% TODO: add a test that verifies that unlocking files and then
%% running the upgrade code is enough to properly upgrade things.

mock_deps(git, Deps, Upgrades) ->
    catch mock_git_resource:unmock(),
    mock_git_resource:mock([{deps, rebar_test_utils:flat_deps(Deps)}, {upgrade, Upgrades}]);
mock_deps(pkg, Deps, Upgrades) ->
    catch mock_pkg_resource:unmock(),
    mock_pkg_resource:mock([{pkgdeps, rebar_test_utils:flat_pkgdeps(Deps)}, {upgrade, Upgrades}]).

mock_deps(git, _OldDeps, Deps, Upgrades) ->
    catch mock_git_resource:unmock(),
    mock_git_resource:mock([{deps, rebar_test_utils:flat_deps(Deps)}, {upgrade, Upgrades}]);
mock_deps(pkg, OldDeps, Deps, Upgrades) ->
    Merged = Deps ++ [Dep || Dep <- OldDeps,
                             not lists:keymember(element(1, Dep), 1, Deps)],
    catch mock_pkg_resource:unmock(),
    mock_pkg_resource:mock([{pkgdeps, rebar_test_utils:flat_pkgdeps(Merged)}, {upgrade, Upgrades}]).

normalize_unlocks({App, Locks}) ->
    {iolist_to_binary(App),
     normalize_unlocks_expect(Locks)};
normalize_unlocks({App, Vsn, Locks}) ->
    {iolist_to_binary(App), iolist_to_binary(Vsn),
     normalize_unlocks_expect(Locks)}.

normalize_unlocks_expect({error, Reason}) ->
    {error, Reason};
normalize_unlocks_expect([]) ->
    [];
normalize_unlocks_expect([{App,Vsn} | Rest]) ->
    [{dep, App, Vsn},
     {lock, App, Vsn}
     | normalize_unlocks_expect(Rest)];
normalize_unlocks_expect([App | Rest]) ->
    [{dep, App},
     {lock, App} | normalize_unlocks_expect(Rest)].

top_a(Config) -> run(Config).
top_b(Config) -> run(Config).
top_c(Config) -> run(Config).
top_d1(Config) -> run(Config).
top_d2(Config) -> run(Config).
top_e(Config) -> run(Config).

pair_a(Config) -> run(Config).
pair_b(Config) -> run(Config).
pair_ab(Config) -> run(Config).
pair_c(Config) -> run(Config).
pair_all(Config) -> run(Config).

triplet_a(Config) -> run(Config).
triplet_b(Config) -> run(Config).
triplet_c(Config) -> run(Config).

tree_a(Config) -> run(Config).
tree_b(Config) -> run(Config).
tree_c(Config) -> run(Config).
tree_c2(Config) -> run(Config).
tree_ac(Config) -> run(Config).
tree_all(Config) -> run(Config).
promote(Config) -> run(Config).

delete_d(Config) ->
    meck:new(rebar_log, [no_link, passthrough]),
    run(Config),
    Infos = [{Str, Args}
            || {_, {rebar_log, log, [info, Str, Args]}, _} <- meck:history(rebar_log)],
    meck:unload(rebar_log),
    ?assertNotEqual([],
                    [1 || {"App ~ts is no longer needed and can be deleted.",
                           [<<"D">>]} <- Infos]).

stable_lock(Config) ->
    apply(?config(mock, Config), []),
    {ok, RebarConfig} = file:consult(?config(rebarconfig, Config)),
    %% Install dependencies before re-mocking for an upgrade
    rebar_test_utils:run_and_check(Config, RebarConfig, ["lock"], {ok, []}),
    {App, Unlocks} = ?config(expected, Config),
    ct:pal("Upgrades: ~p -> ~p", [App, Unlocks]),
    Expectation = case Unlocks of
        {error, Term} -> {error, Term};
        _ -> {ok, Unlocks}
    end,
    apply(?config(mock_update, Config), []),
    NewRebarConf = rebar_test_utils:create_config(?config(apps, Config),
                                                  [{deps, ?config(next_top_deps, Config)}]),
    {ok, NewRebarConfig} = file:consult(NewRebarConf),
    rebar_test_utils:run_and_check(
        Config, NewRebarConfig, ["lock", App], Expectation
    ).

fwd_lock(Config) ->
    apply(?config(mock, Config), []),
    {ok, RebarConfig} = file:consult(?config(rebarconfig, Config)),
    %% Install dependencies before re-mocking for an upgrade
    rebar_test_utils:run_and_check(Config, RebarConfig, ["lock"], {ok, []}),
    {App, Unlocks} = ?config(expected, Config),
    ct:pal("Upgrades: ~p -> ~p", [App, Unlocks]),
    Expectation = case Unlocks of
        {error, Term} -> {error, Term};
        _ -> {ok, Unlocks}
    end,
    rewrite_locks(Expectation, Config),
    apply(?config(mock_update, Config), []),
    NewRebarConf = rebar_test_utils:create_config(?config(apps, Config),
                                                  [{deps, ?config(next_top_deps, Config)}]),
    {ok, NewRebarConfig} = file:consult(NewRebarConf),
    rebar_test_utils:run_and_check(
        Config, NewRebarConfig, ["lock", App], Expectation
    ).

run(Config) ->
    apply(?config(mock, Config), []),
    {ok, RebarConfig} = file:consult(?config(rebarconfig, Config)),
    %% Install dependencies before re-mocking for an upgrade
    rebar_test_utils:run_and_check(Config, RebarConfig, ["lock"], {ok, []}),
    {App, Unlocks} = ?config(expected, Config),
    ct:pal("Upgrades: ~p -> ~p", [App, Unlocks]),
    Expectation = case Unlocks of
        {error, Term} -> {error, Term};
        _ -> {ok, Unlocks}
    end,
    apply(?config(mock_update, Config), []),
    NewRebarConf = rebar_test_utils:create_config(?config(apps, Config),
                                                  [{deps, ?config(next_top_deps, Config)}]),
    {ok, NewRebarConfig} = file:consult(NewRebarConf),
    rebar_test_utils:run_and_check(
        Config, NewRebarConfig, ["upgrade", App], Expectation
    ).

novsn_pkg(Config) ->
    apply(?config(mock, Config), []),
    {ok, RebarConfig} = file:consult(?config(rebarconfig, Config)),
    %% Install dependencies before re-mocking for an upgrade
    rebar_test_utils:run_and_check(Config, RebarConfig, ["lock"], {ok, []}),
    Expectation = ?config(expected, Config),
    apply(?config(mock_update, Config), []),
    rebar_test_utils:run_and_check(
        Config, RebarConfig, ["upgrade"], Expectation
    ),
    ok.

rewrite_locks({ok, Expectations}, Config) ->
    AppDir = ?config(apps, Config),
    LockFile = filename:join([AppDir, "rebar.lock"]),
    {ok, [Locks]} = file:consult(LockFile),
    ExpLocks = [{list_to_binary(Name), Vsn}
               || {lock, Name, Vsn} <- Expectations],
    NewLocks = lists:foldl(
        fun({App, {pkg, Name, _}, Lvl}, Acc) ->
                Vsn = list_to_binary(proplists:get_value(App,ExpLocks)),
                [{App, {pkg, Name, Vsn}, Lvl} | Acc]
        ;  ({App, {git, URL, {ref, _}}, Lvl}, Acc) ->
                Vsn = proplists:get_value(App,ExpLocks),
                [{App, {git, URL, {ref, Vsn}}, Lvl} | Acc]
        end, [], Locks),
    ct:pal("rewriting locks from ~p to~n~p", [Locks, NewLocks]),
    file:write_file(LockFile, io_lib:format("~p.~n", [NewLocks])).
