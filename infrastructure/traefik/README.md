# PostgreSQL TCP access

These overlays extend the existing `traefik` Helm release in namespace `traefik`.
Keep chart version 33.2.1 and reuse the installed values (including the Timeweb
image registry and DaemonSet settings).

First configure the listeners to accept PROXY protocol and expose TCP port 5432:

```sh
helm upgrade traefik traefik --repo https://traefik.github.io/charts --version 33.2.1 --namespace traefik --reuse-values -f infrastructure/traefik/postgresql-values.yaml --wait --timeout 5m
```

Only after Traefik is ready, enable PROXY protocol on the existing Timeweb load
balancer and set `externalTrafficPolicy: Local`. This preserves the client's IP
for the PostgreSQL TCP allowlist, including connections through the NodePort:

```sh
helm upgrade traefik traefik --repo https://traefik.github.io/charts --version 33.2.1 --namespace traefik --reuse-values -f infrastructure/traefik/postgresql-values.yaml -f infrastructure/traefik/loadbalancer-values.yaml --wait --timeout 5m
```

Trusted PROXY protocol senders are restricted to the cluster's private network
192.168.0.0/24. Revisit this range if the private network changes.

The IDEM chart manages the Certificate, MiddlewareTCP and IngressRouteTCP.
The domain is `idem-postgres.thelid.ru`; the public endpoint is port 5432 on the
existing load balancer at 201.34.133.202. DNS must point at that IP for cert-manager
to complete its HTTP-01 challenge. Only addresses in
`postgresql.externalAccess.allowedIPs` can connect; update the dev values if the
workstation's public IP changes.

The PostgreSQL NodePort is pinned to 31349. If the public port 5432 remains
unreachable after updating the Service, check the Timeweb load balancer rules.
On load balancer 145661, the required rule is TCP 5432 -> TCP 31349, targeting
the existing backend worker 192.168.0.5. Preserve the rules for ports 80 and 443.

Clients must use PostgreSQL TLS with SNI (`sslmode=verify-full`, a trusted CA bundle
and hostname `idem-postgres.thelid.ru`). TLS terminates at Traefik; traffic from
Traefik to the database stays inside the cluster. Internal services continue to
use `idem-postgresql:5432`.
