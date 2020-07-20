%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(esockd_limiter_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> esockd_ct:all(?MODULE).

%%--------------------------------------------------------------------
%% Test cases for limiter
%%--------------------------------------------------------------------

t_crud_limiter(_) ->
    {ok, _} = esockd_limiter:start_link(),
    ok = esockd_limiter:create(bucket1, 10),
    ok = esockd_limiter:create(bucket2, 1000, 10),
    #{name     := bucket1,
      capacity := 10,
      interval := 1,
      tokens   := 10
     } = esockd_limiter:lookup(bucket1),
    #{name     := bucket2,
      capacity := 1000,
      interval := 10,
      tokens   := 1000
     } = esockd_limiter:lookup(bucket2),
    Limiters = esockd_limiter:get_all(),
    ?assertEqual(2, length(Limiters)),
    ok = esockd_limiter:delete(bucket1),
    ok = esockd_limiter:delete(bucket2),
    timer:sleep(500), %% wait for deleting
    undefined = esockd_limiter:lookup(bucket1),
    undefined = esockd_limiter:lookup(bucket2),
    ok = esockd_limiter:stop().

t_twice_create(_) ->
    {ok, _} = esockd_limiter:start_link(),
    ok = esockd_limiter:create(bucket1, 10),
    #{name     := bucket1,
      capacity := 10,
      interval := 1,
      tokens   := 10
     } = esockd_limiter:lookup(bucket1),
    {5, 0} = esockd_limiter:consume(bucket1, 5),
    ok = esockd_limiter:create(bucket1, 100),
    #{name     := bucket1,
      capacity := 100,
      interval := 1,
      tokens   := 100
     } = esockd_limiter:lookup(bucket1),
    ok = esockd_limiter:stop().

t_consume(_) ->
    {ok, _} = esockd_limiter:start_link(),
    ok = esockd_limiter:create(bucket, 10, 2),
    #{name     := bucket,
      capacity := 10,
      interval := 2,
      tokens   := 10
     } = esockd_limiter:lookup(bucket),
    {9, 0} = esockd_limiter:consume(bucket),
    #{tokens := 9} = esockd_limiter:lookup(bucket),
    {5, 0} = esockd_limiter:consume(bucket, 4),
    #{tokens := 5} = esockd_limiter:lookup(bucket),
    {0, 2000} = esockd_limiter:consume(bucket, 5),
    #{tokens := 0} = esockd_limiter:lookup(bucket),
    ok = timer:sleep(1000),
    #{tokens := 0} = esockd_limiter:lookup(bucket),
    ok = timer:sleep(1020),
    #{tokens := 10} = esockd_limiter:lookup(bucket),
    {5, 0} = esockd_limiter:consume(bucket, 5),
    {-1, 1000} = esockd_limiter:consume(notexisted, 1),
    ok = esockd_limiter:stop().

t_concurrent_consume(_) ->
    {ok, _} = esockd_limiter:start_link(),
    ConnRate = 10000,
    ok = esockd_limiter:create(bucket, ConnRate, 1),
    Parent = self(),
    Consumer = fun() ->
                   {X, P} = esockd_limiter:consume(bucket, 1),
                   Parent ! {consumer, X, P}
               end,
    Collect = fun _F(0, Acc) -> Acc;
                  _F(N, Acc) ->
                      _F(N-1, [receive M -> M after 1000 -> error(timeout) end | Acc])
              end,
    %% Case1: N*1
    [spawn(Consumer) || _ <- lists:seq(1, ConnRate)],
    ReceviedTokens = Collect(ConnRate, []),
    ct:pal("~p~n", [ReceviedTokens]),
    ?assertEqual(ConnRate, length(lists:usort(ReceviedTokens))),

    %% Case2: N/10 * N
    ok = esockd_limiter:create(bucket, ConnRate, 1),
    [spawn(fun() ->
         [Consumer() || _ <- lists:seq(1, ConnRate div 10)]
     end) || _ <- lists:seq(1, 10)],
    ReceviedTokens2 = Collect(ConnRate, []),
    ct:pal("~p~n", [ReceviedTokens2]),
    ?assertEqual(ConnRate, length(lists:usort(ReceviedTokens2))).

t_handle_call(_) ->
    {reply, ignore, state} = esockd_limiter:handle_call(req, '_From', state).

t_handle_cast(_) ->
  {noreply, state} = esockd_limiter:handle_cast(msg, state).

t_handle_info(_) ->
    {noreply, state} = esockd_limiter:handle_info(info, state).

t_code_change(_) ->
    {ok, state} = esockd_limiter:code_change('OldVsn', state, 'Extra').

