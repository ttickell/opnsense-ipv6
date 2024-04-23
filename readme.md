# IPv6 Dual Wan Fun w/ Opnsense

I recently swapped out my Asus router for an Opnsense box.  Key among the things that "had to work" was dual wan support - I have connections from both Comcast/XFinity and AT&T Fiber.  These are not the same speed connections - AT&T is a 1gb fiber and Comcast is 100mb backup line (after a spade went through the fiber once ...) 

It was quickly clear that this was pretty easy ... with IPv4.  IPv6 presented special fun, especially as I wasn't happy with a default /64 from each provider.

There's a lot of information in the Opnsene and pFsense forums on this - however, I started this repository to publish bits that (hopefully) synthesize these things into working parts that others can use / improve. 

> [!NOTE]
> Legally required disclaimer (ok, not legally) - I'm a middle aged former system administrator who played the jack of all trades, master of none role my entire career.  I am not an IPv6 expert by any stretch of the term.  The entire reason I've been focused on having multiple IPv6 networks is because I wanted to learn more about IPv6.  Please be kind in any commentary pull requests.

# Things of note for context
There are many, many, posts by IPv6 purists about what should or should not work, be required, be done.  This is all about what happens, in practice.  So, a few things that stand out:

* It seems nobody gives out the RFC suggested delegations (save some really niche providers), regardless of what "right" is - and telling Comcast to follow the RFC or mentioning to AT&T what they do is just freaking weird isn't going to add value
* Comcast (at least for me) not only will give out something larger than a /64 - they will in fact give out two /60s
* Comcast is also pretty dang picky about DUID in the DHCP request - since I started with a Raspberry PI running OpenBSD (it's the backup line and I didn't want to break the internet at the house) I had to move the DUID from that box to my Opnsense box
** And THEN Comcast is picky because dhcp6c appears to generate another (subordinate? I haven't read the code) DUID for each PD request - so Comcast has to be first in the delegation requests to _use_ the DUID that was transferred. 
* AT&T gives out plenty of  IPv6 space - one drip at a time.  It seems like they give a /60 to their box, which then will dole out up to eight /64s as unique delegations

In the end, I need to have enough space from both providers that all my primary networks get a /64 from AT&T and they have separate NPTv6 mappings for those spaces in case AT&T goes down and the WAN interfaces failover to Comcast.   Yippee.

Of course, NPTv6 want's a static declaration in Opnsense - so there needs to be shared understanding of what was delegated, even if it wasn't assigned. 

Which DHCP6C doesn't record anywhere  - unless you enable additional logging, and then it's just spewed out to syslog. Well, that's not fair - it does pass the delegations forward to the script run after a dhcp change, but it only passes the prefixes and secondary information - not where /what they were assigned to, like this:

```
PDINFO=2600:1700:60f0:254d::/64 2600:1700:60f0:254c::/64 2600:1700:60f0:254b::/64 2600:1700:60f0:2549::/64 2600:1700:60f0:254f::/64 2600:1700:60f0:254e::/64 
new_domain_name=attlocal.net. 
PWD=/
new_domain_name_servers=2600:1700:60f0:2540::1 
REASON=SOLICIT

-------------------------------
PDINFO=2601:346:27f:3960::/60 2601:346:27f:3b90::/60 
PWD=/
new_domain_name_servers=2001:558:feed::1 2001:558:feed::2 
REASON=REQUEST

```

What I really wanted to have was a the context of delegation and status, as per dhcp6c.  "This delegation as received, this portion of the delegation was used here..."  With that available, I could use the state changes dhcp6c sends to the secondary scripts to trigger calls to the Opnsense API to manage NPT (I think - this is very much a work in progress).

Something like this:

```
root@router:/var/db # cat dhcp6c-pds.json 
{
    "0": {
        "prefix": "2601:346:27f:3960::/60",
        "allocations": false,
        "interfaces": {}
    },
    "1": {
        "prefix": "2601:346:27f:3b90::/60",
        "allocations": false,
        "interfaces": {}
    },
    "2": {
        "prefix": "2600:1700:60f0:254d::/64",
        "allocations": true,
        "interfaces": {
            "igc2": {
                "sla-id": "0",
                "sla-len": "0"
            }
        }
    },
    "3": {
        "prefix": "2600:1700:60f0:254c::/64",
        "allocations": true,
        "interfaces": {
            "igc3": {
                "sla-id": "0",
                "sla-len": "0"
            }
        }
    },
    "4": {
        "prefix": "2600:1700:60f0:254b::/64",
        "allocations": false,
        "interfaces": {}
    },
    "5": {
        "prefix": "2600:1700:60f0:2549::/64",
        "allocations": false,
        "interfaces": {}
    },
    "6": {
        "prefix": "2600:1700:60f0:254f::/64",
        "allocations": false,
        "interfaces": {}
    },
    "7": {
        "prefix": "2600:1700:60f0:254e::/64",
        "allocations": false,
        "interfaces": {}
    }
}
```
# Summation of Goal
* Make DHCP6C get prefix delegations for both providers (see var/etc/dhcp6c.conf.custom)
* Have access to that information (see var/etc/dhcp6-prefix-json)
* Create additional tooling to manage NPT for failover states (see var/etc/dhcp6c-checkset-nptv6)
  * Added note: Chain these scripts from the script in dhcp6c.conf to pick up state changes 
* Pull some cables and see if it actually works (TBD)
* Package this up into something consumable. 

Let's see how this goes.

# 04/22/2024 - Calling this whole thing into question
I spent the weekend torturing python - badly enough that I asked Copilot to "suggest improvements" afterwards and got a lecture on how to be more pythonic - and I have enough bits to make what I wanted to work, work(ish).

But, along the way, I found an article like this:

https://blog.apnic.net/2022/05/16/ula-is-broken-in-dual-stack-networks/

It wasn't that one - that's one I found after the one I found - but it's the same general point: use of ULAs due to RFC 6724 basically means you won't use IPv6, if you have a dual stack network.

I'm struggling with figuring out if I care, or not?  

There is a huge crowd in the IPv6 community I can only describe as purists.  IPv6 is all that there can or should be to them and the fact that IPv4 is not yet dead is like a fish rotting on their favorite pier.  Vile and untouchable, but not something that can be fixed other than to admonish people to not drop their fish.  Part of me - the same part that comes out if your ask me what I think about *nix v. Windows or manual v. automatic - wants to join them and cheer the death of IPv4.   

But there's also the bit that says, "The point of this is to have a network that works between carrier failures."  Does it really matter if a connection is established via IPv4 or IPv6, so long as the end user gets the connection?   Note that the end users, in my case, are my wife and my children.

I made a stupid mistake when I first setup Opnsense: I checked the, "Enable DNS64 Support" box because, of course, why wouldn't you "synthesize AAAA records from A records if not actual AAA records are present".   I then spent the better part of a weekend trying for figure out why one of my wife's must have apps and, for the kids, Brawlstars wasn't working.  A bunch of packet captures later I learned what a few special addresses meant, why their phones were trying to connect to them, and - most importantly - why things were broken because I hadn't enabled the translation to go with the fictitious addresses.

Above I believe I noted I started working on this to learn more about IPv6.  I learned something by enabling DNS64 and breaking things.   

Using a ULA - even if it means my network prefers IPv4 - and ensuring my users (ahem, family) can get connections to services no matter which stack they are usings - strikes me as one of these learning opportunities.   Getting a connection is more important than how the connection was made.  Hell, if they were using IPX/SPX would it really matter?

Yet, part of me wants to side with the article's author and tell the world (in this case my family?) to deal with the outage and interface resets that a provider failure would require, without the use of ULAs, just to be sure we're defaulting to IPv6.

That part of me probably needs to be dragged out back behind a barn, drawn and quartered, shot, and then suffocated.  It's not really a question of which protocol is used, it's a question of did the use case work.

Right?
