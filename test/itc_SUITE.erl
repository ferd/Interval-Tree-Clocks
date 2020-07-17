-module(itc_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-compile([nowarn_export_all, export_all]).

all() -> [{group, basic}, {group, replication}].

groups() ->
    [{basic, [parallel], [demo, version_vector, comparison]},
     {replication, [parallel], [master_to_replicas, master_to_master]}].

%% Testing the demo code from README.markdown to make
%% sure it fits the paper description
demo(_Config) ->
    A0 = itc:seed(),           % a
    {A1, B0} = itc:fork(A0),   % b, A1 = top, B0 = bottom
    A2 = itc:event(A1),        % c (top)
    B1 = itc:event(B0),        % c (bottom)
    {A3, C0} = itc:fork(A2),   % d (top), A3 = top fork, C0 = bottom fork
    B2 = itc:event(B1),        % d (bottom)
    A4 = itc:event(A3),        % e (top)
    BC0 = itc:join(B2, C0),    % e (bottom)
    {BC1, D0} = itc:fork(BC0), % f, BC1 = top fork, D0 = bottom fork
    ABC0 = itc:join(A4, BC1),  % g
    ABC1 = itc:event(ABC0),    % h
    %% Now we assert stuff
    % base: 1, added: 0
    ?assertEqual(A0, {1,0}),
    % 1/2 left, added: 0
    ?assertEqual(A1, {{1,0}, 0}),
    % 1/2 left, added: base 0, left 1, right 0
    ?assertEqual(A2, {{1,0}, {0,1,0}}),
    % 1/4 left, added: base 0, left 1, right 0
    ?assertEqual(A3, {{{1,0},0},{0,1,0}}),
    % 1/4 left, added: base 0, left 1+1/2(left), right 0, left 1
    ?assertEqual(A4, {{{1,0},0},{0,{1,1,0},0}}),
    % 1/2 right, added: 0
    ?assertEqual(B0, {{0,1}, 0}),
    % 1/2 right, added: base 0, left 0, right 1
    ?assertEqual(B1, {{0,1}, {0,0,1}}),
    % 1/2 right, added: base 0, left 0, right 2
    ?assertEqual(B2, {{0,1}, {0,0,2}}),
    % 1/4 left, added: base 0, left 1, right 0
    ?assertEqual(C0, {{{0,1},0},{0,1,0}}),
    % 3/4 right, added: base 1, left 0, right +1 (2)
    ?assertEqual(BC0, {{{0,1},1},{1,0,1}}),
    % fork, keep left BC0, added: base 1, left 0, right 1
    ?assertEqual(BC1, {{{0,1},0},{1,0,1}}),
    % fork, keep 1/2 right, added: base 1, left 0, right 1
    ?assertEqual(D0, {{0,1},{1,0,1}}),
    % merge left for 1/2, base 1, left 1/2l, right 1
    ?assertEqual(ABC0, {{1,0},{1,{0,1,0},1}}),
    % fill gap, 1/2 left, added: base 2
    ?assertEqual(ABC1, {{1,0},2}).

%% Tests that the text from README about replicating Version Vectors
%% with ITCs holds true to its description.
version_vector(_Config) ->
    {A0,Tmp0} = itc:fork(itc:seed()),
    {B0,Tmp1} = itc:fork(Tmp0),
    {C0,D0} = itc:fork(Tmp1),
    %% Check comparisons
    ?assert(equal(A0,B0)),
    ?assert(equal(A0,C0)),
    ?assert(equal(A0,D0)),
    ?assert(equal(B0,C0)),
    ?assert(equal(B0,D0)),
    ?assert(equal(C0,D0)),
    %% events to B & D
    B1 = itc:event(B0),
    D1 = itc:event(D0),
    %% They clash
    ?assertNot(itc:leq(B1,D1)),
    ?assertNot(itc:leq(D1,B1)),
    %% merged replica
    E0 = itc:join(B1,D1),
    %% merge both states
    B2 = itc:join(B1, itc:peek(D1)),
    D2 = itc:join(D1, itc:peek(B1)),
    %% They all compare equivalently
    ?assert(equal(B2,D2)),
    ?assert(equal(B2,E0)),
    ?assert(equal(D2,E0)).

%% The comparison is based on the sequences of events and using
%% leq/2 as an operator. Forks themselves should have no impact.
comparison(_Config) ->
    %% X = X
    A0 = itc:seed(),
    ?assert(itc:leq(A0,A0)),
    %% Forks that are temporally different but have the same
    %% changes are all equal
    {A1, B0} = itc:fork(A0),
    ?assert(itc:leq(A0,A1)),
    ?assert(itc:leq(A1,A0)),
    ?assert(itc:leq(B0,A0)),
    ?assert(itc:leq(B0,A1)),
    ?assert(itc:leq(A0, itc:join(B0,A1))),
    ?assert(itc:leq(itc:join(B0,A1), A0)),
    %% One event leads to a bigger lead everywhere, even if the leading
    %% term is an ancestor (uh-oh!)
    ?assert(itc:leq(A1, itc:event(A0))),
    ?assertNot(itc:leq(itc:event(A0), A1)),
    %% if events are added to both forks, the resulting branches conflict
    %% and are neither smaller, equal, nor greater than each other,
    %% representing concurrent results. They however remain joimable..
    ?assertNot(itc:leq(itc:event(B0), itc:event(A1))),
    ?assertNot(itc:leq(itc:event(A1), itc:event(B0))),
    itc:join(itc:event(A1), itc:event(B0)),
    %% An event added to a parent of a child that also had an event added
    %% could make the parent larger.or smaller. In these cases, joinability
    %% fails.
    ?assertNot(itc:leq(itc:event(A0), itc:event(A1))),
    ?assert(itc:leq(itc:event(A1), itc:event(A0))),
    ?assertError(_, itc:join(itc:event(A1), itc:event(A0))),
    {A2,C0} = itc:fork(A1),
    ?assertNot(itc:leq(itc:event(itc:event(A2)), itc:event(A1))),
    ?assertNot(itc:leq(itc:event(A1), itc:event(itc:event(A2)))),
    ?assertError(_, itc:join(itc:event(A1), itc:event(itc:event(A2)))),
    ?assertNot(itc:leq(itc:event(itc:event(A2)), itc:event(A0))),
    ?assertNot(itc:leq(itc:event(A0), itc:event(itc:event(A2)))),
    ?assertError(_, itc:join(itc:event(A0), itc:event(itc:event(A2)))),
    ?assertNot(itc:leq(itc:event(itc:event(C0)), itc:event(A1))),
    ?assertNot(itc:leq(itc:event(A1), itc:event(itc:event(C0)))),
    ?assertError(_, itc:join(itc:event(A1), itc:event(itc:event(C0)))).

master_to_replicas(_Config) ->
    %% 3 cluster: 1 master, two replicas (A,B)
    {Master0, ReplicaBase} = itc:fork(itc:seed()),
    {ReplicaA0, ReplicaB0} = itc:fork(ReplicaBase),
    %% Simulate 3 unreplicated writes
    Master1 = itc:event(Master0),
    Master2 = itc:event(Master1),
    Master3 = itc:event(Master2),
    %% Replication (peek) and merging (join) should work with the base
    %% state
    ?assert(equal(itc:peek(Master0), itc:peek(ReplicaA0))),
    ?assert(equal(itc:peek(Master0), itc:join(ReplicaA0,Master0))),
    ?assert(equal(itc:peek(Master0),
                  itc:join(ReplicaA0,itc:peek(Master0)))),
    %% Replicate them in order from peek and it should work
    ReplicaA1 = itc:join(ReplicaA0, itc:peek(Master1)),
    ReplicaA2 = itc:join(ReplicaA1, itc:peek(Master2)),
    ReplicaA3 = itc:join(ReplicaA2, itc:peek(Master3)),
    ?assert(equal(itc:peek(Master1), itc:peek(ReplicaA1))),
    ?assert(equal(itc:peek(Master2), itc:peek(ReplicaA2))),
    ?assert(equal(itc:peek(Master3), itc:peek(ReplicaA3))),
    itc:join(Master3,ReplicaA3),
    itc:join(Master3,ReplicaA2),
    itc:join(Master3,ReplicaA1),
    ?assert(smaller(Master2,ReplicaA3)),
    ?assert(smaller(Master1,ReplicaA3)),
    ?assert(smaller(Master0,ReplicaA3)),
    %% Out of order replications for other replica,
    %% from possibly many source
    ?assert(smaller(ReplicaB0,ReplicaA3)),
    ?assert(larger(ReplicaA3,ReplicaB0)),
    ReplicaB1 = itc:join(ReplicaB0, itc:peek(ReplicaA3)),
    ?assert(equal(ReplicaB1, ReplicaA3)),
    ?assert(equal(ReplicaB1, Master3)),
    ?assertNot(smaller(ReplicaB1, Master3)),
    ?assertNot(larger(ReplicaB1, Master3)),
    ?assertNot(smaller(Master3, ReplicaB1)),
    ?assertNot(larger(Master3, ReplicaB1)),
    ok.

master_to_master(_Config) ->
    %% 3 cluster: 1 master, two replicas (A,B)
    {MasterTmp, MasterB0} = itc:fork(itc:seed()),
    {MasterB1, MasterC0} = itc:fork(MasterB0),
    {MasterA0, MasterD0} = itc:fork(MasterTmp),
    %% Concurrent entries can't work, get invalid
    MasterA1 = add_events(3, MasterA0),
    MasterB2 = add_events(2, MasterB1),
    MasterC1 = add_events(1, MasterC0),
    ?assert(clash(MasterA1, MasterB2)),
    ?assert(clash(MasterB2, MasterC1)),
    %% Merges from peek / join work, and supercede the previous values
    ?assert(smaller(MasterC1,
                    itc:join(MasterC1, itc:peek(MasterB2)))),
    ?assert(smaller(MasterC1, itc:join(MasterC1, MasterB2))),
    ?assert(smaller(MasterC1,
                    itc:join(MasterC1, itc:peek(MasterA1)))),
    ?assert(smaller(MasterC1, itc:join(MasterC1, MasterA1))),
    ?assert(smaller(MasterB2,
                    itc:join(MasterC1, itc:peek(MasterB2)))),
    ?assert(smaller(MasterB2, itc:join(MasterC1, MasterB2))),
    ?assert(smaller(MasterA1,
                    itc:join(MasterC1, itc:peek(MasterA1)))),
    ?assert(smaller(MasterA1, itc:join(MasterC1, MasterA1))),
    %% Both merged entries are equal to each other, and still clash
    %% with conflicting ones, but are bigger than sane ones.
    MasterB3 = itc:join(MasterB2, itc:peek(MasterC1)),
    MasterC2 = itc:join(MasterC1, itc:peek(MasterB2)),
    ?assert(equal(MasterB3, MasterC2)),
    ?assert(clash(MasterA1, MasterB3)),
    ?assert(clash(MasterA1, MasterC2)),
    ?assert(smaller(MasterD0, MasterA1)),
    ?assert(smaller(MasterD0, MasterB3)),
    ?assert(smaller(MasterD0, MasterC2)).


equal(ClockA,ClockB) ->
    itc:leq(ClockA,ClockB) andalso itc:leq(ClockB,ClockA).

smaller(ClockA,ClockB) ->
    itc:leq(ClockA,ClockB) andalso not itc:leq(ClockB,ClockA).

larger(ClockA,ClockB) ->
    not itc:leq(ClockA,ClockB) andalso itc:leq(ClockB,ClockA).

clash(ClockA, ClockB) ->
    not equal(ClockA, ClockB) andalso
    not smaller(ClockA, ClockB) andalso
    not larger(ClockA, ClockB).

add_events(0, Clock) -> Clock;
add_events(N, Clock) -> add_events(N-1, itc:event(Clock)).
