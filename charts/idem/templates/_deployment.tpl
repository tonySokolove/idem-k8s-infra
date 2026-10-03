{{/*
Общий Deployment для типового HTTP-сервиса IDEM: один контейнер, порт http, /health-пробы.
Вызов из templates/<service>/deployment.yaml:
  {{ include "idem.deployment" (dict "name" "<service>" "root" $) }}

Шаблон намеренно не расширяется под частные случаи. Если сервису нужно то, чего здесь нет
(sidecar, volumes, init-контейнер, другие пробы), не добавляйте параметр сюда:
замените include в папке этого сервиса на его собственный полный манифест.
*/}}
{{- define "idem.deployment" -}}
{{- $name := .name }}
{{- $root := .root }}
{{- $service := include "idem.service.values" . | fromYaml }}
{{- if $service.enabled }}
{{- $ctx := dict "name" $name "service" $service "root" $root }}
{{- $env := concat ($service.env | default list) ($service.extraEnv | default list) }}
apiVersion: apps/v1
kind: Deployment

metadata:
  name: {{ include "idem.fullname" $name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "idem.labels" $ctx | nindent 4 }}

spec:
  replicas: {{ default 1 $service.replicas }}
  revisionHistoryLimit: 1

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  selector:
    matchLabels:
      {{- include "idem.selectorLabels" $ctx | nindent 6 }}

  template:
    metadata:
      labels:
        {{- include "idem.labels" $ctx | nindent 8 }}

    spec:
      {{- with $root.Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      containers:
        - name: {{ include "idem.fullname" $name }}

          image: {{ include "idem.image" $ctx | quote }}

          imagePullPolicy: IfNotPresent

          {{- with $env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}

          ports:
            - name: http
              containerPort: {{ default 8080 $service.port }}

          resources:
            {{- if $service.resources }}
            {{- toYaml $service.resources | nindent 12 }}
            {{- else }}
            {{- toYaml $root.Values.global.resources | nindent 12 }}
            {{- end }}

          # Даёт медленно стартующим сервисам (Spring Boot на малом CPU) время подняться,
          # прежде чем liveness начнёт перезапускать pod
          startupProbe:
            httpGet:
              path: {{ default "/health" $service.healthPath }}
              port: http

            periodSeconds: 5
            failureThreshold: {{ default 24 $service.startupFailureThreshold }}

          readinessProbe:
            httpGet:
              path: {{ default "/health" $service.healthPath }}
              port: http

            initialDelaySeconds: 2
            periodSeconds: 5

          livenessProbe:
            httpGet:
              path: {{ default "/health" $service.healthPath }}
              port: http

            initialDelaySeconds: 5
            periodSeconds: 10
{{- end }}
{{- end }}
