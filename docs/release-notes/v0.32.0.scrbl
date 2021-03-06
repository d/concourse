#lang scribble/manual

@title[#:style '(quiet unnumbered)]{v0.32.0}

@itemlist[
  @item{
    The faux 'back' button on the build view page has been replaced with the
    navigation bar from the main page.
  }

  @item{
    The ATC's logging level can be reconfigured via the API. Getting and setting
    it is done via @code{GET} and @code{PUT} to @code{/api/v1/log-level}. Valid
    values are @code{debug}, @code{info}, @code{error}, and @code{fatal}.

    Additional logging has been added at the @code{debug} level, now that it can
    be kept quiet by default.
  }

  @item{
    Fixed a bug that could cause pending builds of serial jobs to never run.
    Upgrading prevents this and will fix any stuck jobs.
  }

  @item{
    The main page is now durable to network errors, and will continue to update.
  }

  @item{
    Pending builds can now be aborted again.
  }
]
