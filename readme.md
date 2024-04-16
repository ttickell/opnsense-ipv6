# IPv6 Dual Wan Fun w/ Opnsense

I recently swapped out my Asus router for an Opnsense box.  Key among the things that "had to work" was dual wan support - I have connections from both Comcast/XFinity and AT&T Fiber.  These are not the same speed connections - AT&T is a 1gb fiber and Comcast is 100mb backup line (after a spade went through the fiber once ...) 

It was quickly clear that this was pretty easy ... with IPv4.  IPv6 presented special fun, especially as I wasn't happy with a default /64 from each provider.

There's a lot of information in the Opnsene and pFsense forums on this - however, I started this repository to publsh bits that (hopefully) synthesize these things into working parts that others can use / improve. 

[!NOTE]
Legally required disclaimer (ok, not legally) - I a middle aged system administrator who's played the jack of all trades, master of none role my entire career.  I am not an IPv6 expert by any stretch of the term.  The entire reason I've been focused on having multiple IPv6 networks is because I wanted to learn more about IPv6.  Please be kind in any commentary an pull requests.

# Things of note for context
There are many, many, posts by IPv6 purists about what should or should not work, be required, be done.  This is all about what happens, in practice.  So, a few things that stand out:

* No body give the RFC suggested delegations, regardless of what "right" is - and telling Comcast to follow the RFC or mentioning to AT&T what they do is just freaking weird isn't going to add value
* Comcast (at least for me) not only will give out something larger than a /64 - they will in fact give out two /60s
* Comcast is also pretty dang picky about DUID in the DHCP request - since I started with a Raspberry PI running OpenBSD (it's the backup line and I didn't want to break the internet at the house) I had to move the DUID from that box to my Opnsense box
** And THEN Comcast is picky because dhcp6c appears to generate another (subordinate? I haven't read the code) DUID for each PD request - so Comcast has to be first in the delegation requests to _use_ the DUID that was transfered. 
* AT&T give out plenty of  IPv6 space - one drip at at time.  It seems like they give a /60 to their box, which then will dole out up to eight /64s as unique delegations

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

What I really wanted to have was a the context 
