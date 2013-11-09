# Interval Tree Clocks


Classic causality tracking mechanisms, such as version vectors and vector clocks, have been designed under the assumption of a fixed, well known, set of participants. These mechanisms are less than ideal when applied to dynamic scenarios, subject to variable numbers of participants and churn. E.g. in the Amazon Dynamo system old entries on version vectors are pruned to conserve space, and errors can be introduced.

Interval Tree Clocks (ITC) is a new clock mechanism that can be used in scenarios with a dynamic number of participants, allowing a completely decentralized creation of processes/replicas without need for global identifiers. The mechanism has a variable size representation that adapts automatically to the number of existing entities, growing or shrinking appropriately.

Here we provide reference implementations of ITCs in Java, C and Erlang, and appropriate import and export methods to a common serialized representation. In Sample Run we provide an example on how to use the API in both languages. Further information can be found here and full details in the Conference Paper, published in Opodis 2009.



## Simple demo run



### Demo run

The image shows a run from ITC witch is divided in sections. Each section represents the state of the system between operations (_fork_, _event_ or _join_) and is labeled with a letter. This letter maps the state of the operations presented in both demo programs.

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

TODO: Add version vector simulation example in Erlang
