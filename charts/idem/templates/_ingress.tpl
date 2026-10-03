{{/*
Общий Ingress через Traefik (websecure) с сертификатом Let's Encrypt.
Вызов из templates/<service>/ingress.yaml:
  {{ include "idem.ingress" (dict "name" "<service>" "root" $) }}
Нет файла ingress.yaml в папке сервиса — нет внешнего адреса.
Особый случай (несколько хостов, path-маршруты, middleware) — полный манифест в папке сервиса.
*/}}
{{- define "idem.ingress" -}}
{{- $name := .name }}
{{- $root := .root }}
{{- $service := include "idem.service.values" . | fromYaml }}
{{- if and $service.enabled $service.ingress $service.ingress.enabled }}
{{- $ctx := dict "name" $name "service" $service "root" $root }}
{{- $host := required (printf "services.%s.ingress.host is required" $name) $service.ingress.host }}
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: {{ include "idem.fullname" $name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "idem.labels" $ctx | nindent 4 }}

  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"

spec:
  ingressClassName: traefik

  tls:
    - hosts:
        - {{ $host }}

      secretName: {{ include "idem.fullname" $name }}-tls

  rules:
    - host: {{ $host }}

      http:
        paths:
          - path: /
            pathType: Prefix

            backend:
              service:
                name: {{ include "idem.fullname" $name }}

                port:
                  number: {{ default 80 $service.servicePort }}
{{- end }}
{{- end }}
