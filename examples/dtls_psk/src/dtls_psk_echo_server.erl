%% Copyright (c) 2018 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(dtls_psk_echo_server).

-export([start/0, start/1]).

-export([start_link/2, loop/2]).

start() ->
    start(5000).
start(Port) ->
    [{ok, _} = application:ensure_all_started(App) || App <- [sasl, crypto, ssl, esockd]],
    DtlsOpts = [{mode, binary}, {reuseaddr, true}] ++ psk_opts(),
    Opts = [{acceptors, 4}, {max_clients, 1000}, {dtls_options, DtlsOpts}],
    {ok, _} = esockd:open_dtls('echo/dtls', Port, Opts, {?MODULE, start_link, []}).

start_link(Transport, Peer) ->
    {ok, spawn_link(?MODULE, loop, [Transport, Peer])}.

loop(Transport = {dtls, SockPid, _}, Peer) ->
    receive
        {datagram, SockPid, Packet} ->
            io:format("~s - ~p~n", [esockd_net:format(peername, Peer), Packet]),
            SockPid ! {datagram, Peer, Packet},
            loop(Transport, Peer)
    end.

user_lookup(psk, ClientPSKID, UserState) ->
    io:format("ClientPSKID: ~p, Userstate: ~p~n", [ClientPSKID, UserState]),
    {ok, UserState}.

psk_opts() -> [
     {verify, verify_none},
     {protocol, dtls},
     {versions, [dtlsv1, 'dtlsv1.2']},
     {ciphers, [{psk,aes_128_cbc,sha}, {rsa_psk,aes_128_cbc,sha256}]},
     {user_lookup_fun, {fun user_lookup/3, <<"shared_secret">>}}
].
