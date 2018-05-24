Here we can define modules and classes for noop mode.

Instead of polluting code with AppOpticsAPM.loaded conditionals

we load these classes when in noop mode and they expose noop behavior.

so far only one class is needed:

- AppOpticsAPM::Context  and its toString() method from oboe