#lang scribble/manual

@(require "../common.rkt")

@title[#:version version #:tag "deploying-with-bosh"]{Deploying a cluster with BOSH}

Once you start needing more workers and @emph{really} caring about your CI
deployment, it's best to manage it with BOSH proper.

Using BOSH gives you a self-healing, predictable environment, that can be
scaled up or down by changing a single number.

The @hyperlink["https://bosh.io/docs"]{BOSH documentation} outlines the
concepts, and how to bootstrap on various infrastructures.


@section{Setting up the infrastructure}

Step one is to pick your infrastructure. AWS, vSphere, and OpenStack are fully
supported by BOSH.
@hyperlink["https://github.com/cloudfoundry/bosh-lite"]{BOSH-Lite} is
a pseudo-infrastructure that deploys everything within a single VM. It is
a great way to get started with Concourse and BOSH at the same time, with
a faster feedback loop.

Concourse's infrastructure requirements are fairly straightforward. For
example, Concourse's own pipeline is deployed within an AWS VPC, with its web
instances automatically registered with an Elastic Load Balancer by BOSH.

@hyperlink["http://consul.io"]{Consul} is baked into the BOSH release, so that
you only need to configure static IPs for the Consul servers, and then
configure the Consul agents on the other jobs to join with the server. This
way you can have 100 workers without having to configure them 100 times.


@subsection{BOSH-Lite}

Learning BOSH and your infrastructure at the same time will probably be hard.
If you're getting started with BOSH, you may want to check out
@hyperlink["https://github.com/cloudfoundry/bosh-lite"]{BOSH-Lite} first,
which gives you a fairly BOSHy experience, in a single VM on your machine.
This is a good way to learn the BOSH tooling without having to pay hourly for
AWS instances.


@subsection{AWS}

For AWS, it is recommended to deploy Concourse within a VPC, with the
@code{web} jobs sitting behind an ELB. Registering instances with the ELB is
automated by BOSH; you'll just have to create the ELB itself. This
configuration is more secure, as your CI system's internal jobs aren't exposed
to the outside world.


@subsection{vSphere, OpenStack}

Deploying to vSphere and OpenStack should look roughly the same as the rest,
but this configuration has so far not seen any mileage. You may want to
consult the @hyperlink["http://docs.cloudfoundry.org/bosh/"]{BOSH
documentation} instead.


@section{Deploying and upgrading Concourse}

Once you've set up BOSH on your infrastructure, the following steps should get
you started:


@subsection{Upload the stemcell}

A stemcell is a base image for your VMs. It controls the kernel and OS
distribution, and the version of the BOSH agent. For more information, consult
the @hyperlink["http://bosh.io/docs/stemcell.html"]{BOSH documentation}.

To upload the latest AWS Trusty stemcell to your BOSH director, execute the
following:

@codeblock|{
bosh upload stemcell https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent
}|


@subsection{Upload the Concourse & Garden releases}

A release is a curated distribution of all of the source bits and
configuration necessary to deploy and scale a product. To learn more about
BOSH releases, refer to the
@hyperlink["http://bosh.io/docs/release.html"]{BOSH documentation}.

A Concourse deployment currently requires two releases:
@hyperlink["http://github.com/concourse/concourse"]{Concourse}'s release
itself, and
@hyperlink["http://github.com/cloudfoundry-incubator/garden-linux-release"]{Garden
Linux}, which it uses for container management.

To upload the latest version of both releases, execute:

@codeblock|{
bosh upload release https://bosh.io/d/github.com/concourse/concourse
bosh upload release https://bosh.io/d/github.com/cloudfoundry-incubator/garden-linux-release
}|

Note that as these are technically two separate releases, there is no
guarantee that they work together at all times. Concourse depends on Garden
Linux, and while each release does go through its own CI pipeline, there's
a chance that Garden Linux makes a backwards-incompatible change.

Currently the safest way to know which Garden Linux version to use is to go
to our
@hyperlink["https://github.com/concourse/concourse/releases/latest"]{latest
GitHub release} and grab Concourse and Garden-Linux from the @emph{Downloads}
section. You can give these URLs directly to @code{bosh upload release} as
well.


@subsection[#:tag "bosh-properties"]{Configure & Deploy}

All you need to deploy your entire Concourse cluster is a BOSH deployment
manifest. This single document describes the desired layout of an entire
cluster.

The Concourse repo contains a few example manifests:

@itemlist[
  @item{
    @hyperlink["https://github.com/concourse/concourse/blob/develop/manifests/bosh-lite.yml"]{BOSH Lite}
  }

  @item{
    @hyperlink["https://github.com/concourse/concourse/blob/develop/manifests/aws-vpc.yml"]{AWS VPC}
  }
]

If you reuse these manifests, you'll probably want to change the following
values:

@itemlist[
  @item{
    @code{director_uuid}: The UUID of your deployment's BOSH director. Obtain
    this with @code{bosh status --uuid}. This is a safeguard against deploying
    to the wrong environments (the risk of making deploys so automated.)
  }

  @item{
    @code{networks}: Your infrastructure's IP ranges and such will probably be
    different, but may end up being the same if you're using AWS with a VPC
    that's the same CIDR block.
  }

  @item{
    @code{jobs.discovery.networks.X.static_ips}: A set of static IPs within
    your network, used for each of the Consul servers.

    When changing this, be careful to update each job's
    @code{consul.agent.servers.lan} property to include the full set of IPs.

    For a small-scale deployment, a single Consul server is probably fine. For
    HA, you'll probably want to scale up to 3 or so. Refer to
    @hyperlink["http://consul.io"]{Consul}'s documentation for more
    information.
  }

  @item{
    @code{jobs.web.properties.atc.basic_auth_username},
    @code{jobs.web.properties.atc.basic_auth_encrypted_password}: Basic auth
    credentials for the public web server.

    The password must be a BCrypt-encrypted string. Note that higher encryption
    costs may make the site less responsive.
  }

  @item{
    @code{jobs.worker.gate.atc.username},
    @code{jobs.worker.gate.atc.password}: Basic auth credentials to use when
    registering the worker. These must be specified if basic auth is
    configured, otherwise no workers will be available.

    These are the same credentials as above, only in plaintext. Yes, it's kind
    of silly. We'd like to improve this in the future.
  }

  @item{
    @code{jobs.web.properties.atc.publicly_viewable}: Set to @code{true} to
    make the webserver open (read-only) to the public. Destructive operations
    are not permitted sensitive data is hidden when unauthenticated.
  }

  @item{
    @code{jobs.db.properties.postgresql.roles} and
    @code{jobs.web.properties.atc.postgresql.role}: The credentials to the
    PostgreSQL instance.
  }

  @item{
    @code{jobs.db.persistent_disk}: How much space to give PostgreSQL. You can
    change this at any time; BOSH will safely migrate your persistent data to
    a new disk when scaling up.
  }

  @item{
    @code{jobs.worker.instances}: Change this number to scale up or down the
    number of worker VMs. Concourse will randomly pick a VM out of this pool
    every time it starts a build.
  }

  @item{
    @code{resource_pools}: This is where you configure things like your EC2
    instance type, the ELB to register your instances in, etc.
  }
]

You can change these values at any time and BOSH deploy again, and BOSH will do
The Right Thing™. It will tear down VMs as necessary, but always make sure
persistent data persists, and things come up as they should.

Once you have a deployment manifest, deploying Concourse should simply be:

@codeblock|{
$ bosh deployment path/to/manifest.yml
$ bosh deploy
}|

When new Concourse versions come out, upgrading should simply be a matter of
uploading the new releases and deploying again. BOSH will then kick off a
rolling deploy of your cluster.

@inject-analytics[]
