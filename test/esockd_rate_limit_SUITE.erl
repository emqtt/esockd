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

-module(esockd_rate_limit_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> esockd_ct:all(?MODULE).

t_info(_) ->
    Rl = esockd_rate_limit:new({1, 10}),
    Info = esockd_rate_limit:info(Rl),
    ?assertMatch(#{rate   := 1,
                   burst  := 10,
                   tokens := 10
                  }, Info),
    ?assert(erlang:system_time(milli_seconds) >= maps:get(time, Info)).

t_check(_) ->
    Rl = esockd_rate_limit:new({1, 10}),
    #{tokens := 10} = esockd_rate_limit:info(Rl),
    {0, Rl1} = esockd_rate_limit:check(5, Rl),
    #{tokens := 5} = esockd_rate_limit:info(Rl1),
    %% P = 1/r = 1000ms
    {1000, Rl2} = esockd_rate_limit:check(5, Rl1),
    #{tokens := 0} = esockd_rate_limit:info(Rl2),
    %% P = (Tokens-Limit)/r = 5000ms
    {5000, Rl3} = esockd_rate_limit:check(5, Rl2),
    #{tokens := 0} = esockd_rate_limit:info(Rl3),
    ok = timer:sleep(1000),
    %% P = (Tokens-Limit)/r = 1000ms
    {1000, _} = esockd_rate_limit:check(2, Rl3).

t_check_bignum(_) ->
    R1 = 30000000,
    R2 = 15000000,
    Rl = esockd_rate_limit:new({R1, R1}),
    #{tokens := R1} = esockd_rate_limit:info(Rl),
    {0, Rl1} = esockd_rate_limit:check(R2, Rl),
    #{tokens := R2} = esockd_rate_limit:info(Rl1),
    %% P = 1/r = 0.00003333 ~= 0ms
    {0, Rl2} = esockd_rate_limit:check(R2, Rl1),
    #{tokens := 0} = esockd_rate_limit:info(Rl2),

    timer:sleep(1000),
    %% P = (Tokens-Limit)/r = 1000ms
    {1000, Rl3} = esockd_rate_limit:check(R1*2, Rl2),
    #{tokens := 0} = esockd_rate_limit:info(Rl3),
    %% P = (Tokens-Limit)/r = 0.5ms ~= 1ms
    {1, Rl4} = esockd_rate_limit:check(R1*(1+0.0005), Rl2),
    #{tokens := 0} = esockd_rate_limit:info(Rl4).

