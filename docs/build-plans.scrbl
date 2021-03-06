#lang scribble/manual

@(require "common.rkt")

@title[#:style 'toc #:version version #:tag "build-plans"]{Build Plans}

Each @seclink["jobs"]{Job} has a single build plan. When a build of a job is
created, the plan determines what happens.

A build plan is a sequence of @emph{steps} to execute. These steps may fetch
down or update @seclink["resources"]{Resources}, or execute
@seclink["tasks"]{Tasks}.

A new build of the job is scheduled whenever any of the resources described
by the first @seclink["get-step"]{@code{get}} steps have new versions.

To visualize the job in the pipeline, resources that appear as @code{get}
steps are drawn as inputs, and resources that appear in @code{put} steps
appear as outputs.

A simple unit test job may look something like:

@codeblock|{
name: banana-unit
plan:
- get: banana
- task: unit
  file: banana/task.yml
}|

This job says: @seclink["get-step"]{@code{get}} the @code{banana} resource,
and run a @seclink["task-step"]{@code{task}} step called @code{unit}, using
the configuration from the @code{task.yml} file fetched from the @code{banana}
step.

When new versions of @code{banana} are detected, a new build of
@code{banana-unit} will be scheduled.

Jobs can depend on resources that are produced by or pass through upstream
jobs, by configuring @code{passed: [job-a, job-b]} on the
@seclink["get-step"]{@code{get}} step.

Putting these pieces together, if we were to propagate @code{banana} from
the above example into an integration suite with another @code{apple}
component (pretending we also defined its @code{apple-unit} job), the
configuration for the integration job may look something like:

@codeblock|{
name: fruit-basket-integration
plan:
- aggregate:
  - get: banana
    passed: [banana-unit]
  - get: apple
    passed: [apple-unit]
  - get: integration-suite
- task: integration
  file: integration-suite/task.yml
}|

Note the use of the @seclink["aggregate-step"]{@code{aggregate}} step to
collect multiple inputs at once.

With this example we've configured a tiny pipeline that will automatically
run unit tests for two components, and continuously run integration tests
against whichever versions pass both unit tests.

This can be further chained into later "stages" of your pipeline; for
example, you may want to continuously deliver an artifact built from
whichever components pass @code{fruit-basket-integration}.

To push artifacts, you would use a @seclink["put-step"]{@code{put}} step
that targets the destination resource. For example:

@codeblock|{
name: deliver-food
plan:
- aggregate:
  - get: banana
    passed: [fruit-basket-integration]
  - get: apple
    passed: [fruit-basket-integration]
  - get: baggy
- task: shrink-wrap
  file: baggy/shrink-wrap.yml
- put: bagged-food
  params:
    bag: shrink-wrap/bagged.tgz
}|

This presumes that there's a @code{bagged-food}
@seclink["resources"]{resource} defined, which understands that the
@code{bag} parameter points to a file to ship up to the resource's location.

Note that both @code{banana} and @code{apple} list the same job as an
upstream dependency. This guarantees that @code{deliver-food} will only
trigger when a version of both of these dependencies pass through the same
build of the integration job (and transitively, their individual unit jobs).
This prevents bad apples or bruised bananas from being delivered. (I'm sorry.)

For a reference on each type of step, read on.

@table-of-contents[]

@include-section{steps/get.scrbl}
@include-section{steps/put.scrbl}
@include-section{steps/task.scrbl}
@include-section{steps/aggregate.scrbl}
@include-section{steps/do.scrbl}
@include-section{steps/conditions.scrbl}

@inject-analytics[]
