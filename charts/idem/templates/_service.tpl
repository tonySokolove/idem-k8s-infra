{{/*
Общий ClusterIP Service: порт servicePort (по умолчанию 80) → именованный порт http контейнера.
Вызов из templates/<service>/service.yaml:
  {{ include "idem.service" (dict "name" "<service>" "root" $) }}
Особый случай (несколько портов, headless и т.п.) — полный манифест в папке сервиса.
*/}}
{{- define "idem.service" -}}
{{- $name := .name }}
{{- $root := .root }}
{{- $service := include "idem.service.values" . | fromYaml }}
{{- if $service.enabled }}
{{- $ctx := dict "name" $name "service" $service "root" $root }}
apiVersion: v1
kind: Service

metadata:
  name: {{ include "idem.fullname" $name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "idem.labels" $ctx | nindent 4 }}

spec:
  type: ClusterIP

  selector:
    {{- include "idem.selectorLabels" $ctx | nindent 4 }}

  ports:
    - name: http
      port: {{ default 80 $service.servicePort }}
      targetPort: http
{{- end }}
{{- end }}
