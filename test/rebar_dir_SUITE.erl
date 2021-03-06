-module(rebar_dir_SUITE).

-export([all/0, init_per_testcase/2, end_per_testcase/2]).

-export([default_src_dirs/1, default_extra_src_dirs/1, default_all_src_dirs/1]).
-export([src_dirs/1, extra_src_dirs/1, all_src_dirs/1]).
-export([profile_src_dirs/1, profile_extra_src_dirs/1, profile_all_src_dirs/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").


all() -> [default_src_dirs, default_extra_src_dirs, default_all_src_dirs,
          src_dirs, extra_src_dirs, all_src_dirs,
          profile_src_dirs, profile_extra_src_dirs, profile_all_src_dirs].

init_per_testcase(_, Config) ->
    C = rebar_test_utils:init_rebar_state(Config),
    AppDir = ?config(apps, C),

    Name = rebar_test_utils:create_random_name("app1_"),
    Vsn = rebar_test_utils:create_random_vsn(),
    rebar_test_utils:create_app(AppDir, Name, Vsn, [kernel, stdlib]),
    C.

end_per_testcase(_, _Config) -> ok.

default_src_dirs(Config) ->
    {ok, State} = rebar_test_utils:run_and_check(Config, [], ["compile"], return),
    
    [] = rebar_dir:src_dirs(State),
    ["src"] = rebar_dir:src_dirs(State, ["src"]).

default_extra_src_dirs(Config) ->
    {ok, State} = rebar_test_utils:run_and_check(Config, [], ["compile"], return),
  
    [] = rebar_dir:extra_src_dirs(State),
    ["src"] = rebar_dir:extra_src_dirs(State, ["src"]).

default_all_src_dirs(Config) ->
    {ok, State} = rebar_test_utils:run_and_check(Config, [], ["compile"], return),
  
    [] = rebar_dir:all_src_dirs(State),
    ["src", "test"] = rebar_dir:all_src_dirs(State, ["src"], ["test"]).

src_dirs(Config) ->
    RebarConfig = [{erl_opts, [{src_dirs, ["foo", "bar", "baz"]}]}],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["compile"], return),
    
    ["foo", "bar", "baz"] = rebar_dir:src_dirs(State).

extra_src_dirs(Config) ->
    RebarConfig = [{erl_opts, [{extra_src_dirs, ["foo", "bar", "baz"]}]}],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["compile"], return),
    
    ["foo", "bar", "baz"] = rebar_dir:extra_src_dirs(State).

all_src_dirs(Config) ->
    RebarConfig = [{erl_opts, [{src_dirs, ["foo", "bar"]}, {extra_src_dirs, ["baz", "qux"]}]}],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["compile"], return),
    
    ["foo", "bar", "baz", "qux"] = rebar_dir:all_src_dirs(State).

profile_src_dirs(Config) ->
    RebarConfig = [
        {erl_opts, [{src_dirs, ["foo", "bar"]}]},
        {profiles, [
            {more, [{erl_opts, [{src_dirs, ["baz", "qux"]}]}]}
        ]}
    ],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["as", "more", "compile"], return),
    
    R = lists:sort(["foo", "bar", "baz", "qux"]),
    R = lists:sort(rebar_dir:src_dirs(State)).

profile_extra_src_dirs(Config) ->
    RebarConfig = [
        {erl_opts, [{extra_src_dirs, ["foo", "bar"]}]},
        {profiles, [
            {more, [{erl_opts, [{extra_src_dirs, ["baz", "qux"]}]}]}
        ]}
    ],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["as", "more", "compile"], return),
    
    R = lists:sort(["foo", "bar", "baz", "qux"]),
    R = lists:sort(rebar_dir:extra_src_dirs(State)).

profile_all_src_dirs(Config) ->
    RebarConfig = [
        {erl_opts, [{src_dirs, ["foo"]}, {extra_src_dirs, ["bar"]}]},
        {profiles, [
            {more, [{erl_opts, [{src_dirs, ["baz"]}, {extra_src_dirs, ["qux"]}]}]}
        ]}
    ],
    {ok, State} = rebar_test_utils:run_and_check(Config, RebarConfig, ["as", "more", "compile"], return),
    
    R = lists:sort(["foo", "bar", "baz", "qux"]),
    R = lists:sort(rebar_dir:all_src_dirs(State)).
