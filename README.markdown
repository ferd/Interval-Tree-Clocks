# Interval Tree Clocks


Classic causality tracking mechanisms, such as version vectors and vector clocks, have been designed under the assumption of a fixed, well known, set of participants. These mechanisms are less than ideal when applied to dynamic scenarios, subject to variable numbers of participants and churn. E.g. in the Amazon Dynamo system old entries on version vectors are pruned to conserve space, and errors can be introduced.

Interval Tree Clocks (ITC) is a new clock mechanism that can be used in scenarios with a dynamic number of participants, allowing a completely decentralized creation of processes/replicas without need for global identifiers. The mechanism has a variable size representation that adapts automatically to the number of existing entities, growing or shrinking appropriately.

This repository gives a usable implementation in Erlang forked from the [original tri-lingual reference implementation](https://github.com/ricardobcl/Interval-Tree-Clocks). Further information can be found here and full details in the [Conference Paper, published in Opodis 2009](http://gsd.di.uminho.pt/members/cbm/ps/itc2008.pdf).

## Simple demo run

### Demo run

The image shows a run from ITC which is divided in sections. Each section represents the state of the system between operations (_fork_, _event_ or _join_) and is labeled with a letter. This letter maps the state of the operations presented in both demo programs.

<a href="http://picasaweb.google.com/lh/photo/07P2CBMlkfauJ651E6eYpQ?feat=embedwebsite"><img src="http://lh3.ggpht.com/_tR0W8QwQsQY/S4ULQBCxDKI/AAAAAAAAAfQ/XW4C9AwOmJc/s800/execFlow.png" /></a>

### Demo code

```erlang

A0 = itc:seed(), % a

{A1, B0} = itc:fork(A0), % b, A1 = top, B0 = bottom

A2 = itc:event(A1), % c (top)
B1 = itc:event(B0), % c (bottom)

{A3, C0} = itc:fork(A2), % d (top), A3 = top fork, C0 = bottom fork
B2 = itc:event(B1), % d (bottom)

A4 = itc:event(A3), % e (top)
BC0 = itc:join(B2, C0), % e (bottom)

{BC1, D0} = itc:fork(BC0), % f, BC1 = top fork, D0 = bottom fork

ABC0 = itc:join(A4, BC1), % g

ABC1 = itc:event(ABC0). % h

```

## Summary High level presentation of ITCs and its use.


### Introduction 


Interval Tree Clocks can substitute both [Version Vectors](http://en.wikipedia.org/wiki/Version_vector) and [Vector Clocks](http://en.wikipedia.org/wiki/Vector_clock). 

Version Vectors are used to track data dependency among replicas. They are used in replicated file systems (such as [Coda](http://en.wikipedia.org/wiki/Coda_(file_system)) and in Cloud engines (such as [Amazon Dynamo](http://en.wikipedia.org/wiki/Dynamo_(storage_system) and Cassandra). 

Vector Clocks track causality dependency between events in distributed processes. They are used in are used in group communication protocols (such as in the Spread toolkit), in consistent snapshots algorithms, etc.

ITCs can be used in all these settings and will excel in dynamic settings, i.e. whenever the number and set of active entities varies during the system execution, since it allows localized introduction and removal of entities. 
Before ITCs, the typical strategy to address these dynamic settings was to implement the classical vectors as mappings from a globally unique id to an integer counter. The drawback is that unique ids are not space efficient and that if the active entities change over time (under churn) the state dedicated to the mapping will keep growing. This has lead to ad-hoc pruning solutions (e.g. in Dynamo) that can introduce errors and compromise causality tracking. 

ITCs encode the state needed to track causality in a stamp, composed of an event and id component, and introduce 3 basic operations:

*Fork* is used to introduce new stamps. Allows the cloning of the causal past of a stamp, resulting in a pair of stamps that have identical copies of the event component and distinct ids. E.g. it can be used to introduce new replicas to a system.

*Join* is used to merge two stamps. Produces a new stamp that incorporates both causal pasts. E.g. it can be used to retire replicas or receive causal information from messages.

*Event* is used to add causal information to a stamp, "incrementing" the event component and keeping the id.

(*Peek* is a special case of fork that only copies the event component and creates a new stamp with a null id. It can be used to make messages that transport causal information.)


### Simulating Version Vectors

First replicas need to be created. A seed stamp (with a special id component) is first created and the desired number of replicas can be created by forking this initial seed. Bellow we create 4 replicas (`A`, `B`, `C`, and `D`):

```erlang
{A0,Tmp0} = itc:fork(itc:seed()),
{B0,Tmp1} = itc:fork(Tmp0),
{C0,D0} = itc:fork(Tmp1),
```

Since no events have been registered, these stamps all compare as equal. Since a stamp function `leq/2` (less or equal) is provided, stamps `X` and `Y` are equivalent when both `itc:leq(X,Y)` and `itc:leq(Y,X)` are true.

Now, suppose that stamp `B` is associated to a ReplicaB and this replica was modified. We note this by doing:

```erlang
B1 = itc:event(B0),
```

Now stamp `B` is greater than all the others. We can do the same in stamp `D` to denote an update on ReplicaD:

```erlang
D1 = itc:event(D0),
```

These two stamps are now concurrent. Thus `itc:leq(B1,D1)` is false and `itc:leq(D1,B1)` is also false.

Now suppose that we want to merge the updates in ReplicaB and ReplicaD. One way is to create a replica that reflects both updates:

```erlang
E0 = itc:join(B1,D1),
```

This stamp `E` will now have an id that joins the ids in `B` and `D`, and has an event component that holds both issued events. An alternative way, that keeps the number of replicas/stamps and does not form new ids, is to exchange events between both replicas:

```erlang
B2 = itc:join(B1, itc:peek(D1)),
D2 = itc:join(D1, itc:peek(B1)),
```

Now, stamps `B` and `D` are no longer concurrent and will compare as equivalent, since they depict the same events. 


## License

This work is licensed under the Lesser General Public License (LGPL), version
3. See the License for details about distribution rights, and the specific
rights regarding derivate works.

You may obtain a copy of the License at:

http://choosealicense.com/licenses/lgpl-v3/

http://www.gnu.org/licenses/lgpl.html
