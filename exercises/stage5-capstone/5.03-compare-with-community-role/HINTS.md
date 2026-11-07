# 5.03 - Review: your role vs. a community CIS role

## Hint 1

Start with `defaults/main.yml` - variable names reveal the toggle design. Then `tasks/main.yml` for the structure. (Some roles keep the defaults in a `defaults/main/` directory with several files.)

## Hint 2

Search the defaults for words like `disruption`, `workstation`, `level`, `audit`. Tags on the tasks are part of the design, too.

## Hint 3

The skeleton of `review.md` - each answer starts a line with its number, which is what `lab check` looks for:

```
1. How are controls switched on and off?
   - where do the variables live, how are they named, one per control or per group?
   - what does an exception look like in your design, and in theirs?
2. Levels and profiles
   - variable or tag? what do the defaults say for Level 2 and for workstation?
3. Disabled by default
   - which switches default to off or false, and what do they have in common?
4. Two risky controls
   - which task, which guard (a switch, a condition, a warning)?
5. Audit and report
   - check mode or a separate tool? where does the result go, in which format?
6. Decision for 500 servers: adopt, fork or build
   - three risks, three acceptance tests, who reviews each release?
```

There is no single right answer for question 6. A strong answer names concrete risks (update cadence, local deviations, review effort) and a test strategy (lab like this one, Molecule, staged rollout).
