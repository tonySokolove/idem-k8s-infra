{{/*
Имя ресурсов сервиса: idem-<service>.
Вызов: include "idem.fullname" $name
*/}}
{{- define "idem.fullname" -}}
idem-{{ . }}
{{- end }}

{{/*
Selector-метки сервиса. Неизменяемы у Deployment — не менять без пересоздания.
Вызов: include "idem.selectorLabels" (dict "name" $name "root" $)
*/}}
{{- define "idem.selectorLabels" -}}
app.kubernetes.io/name: {{ include "idem.fullname" .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Полный набор меток сервиса.
Вызов: include "idem.labels" (dict "name" $name "service" $service "root" $)
*/}}
{{- define "idem.labels" -}}
{{ include "idem.selectorLabels" . }}
app.kubernetes.io/version: {{ include "idem.imageTag" . | quote }}
app.kubernetes.io/part-of: idem
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end }}

{{/*
Тег образа сервиса с проверкой обязательных полей.
Вызов: include "idem.imageTag" (dict "name" $name "service" $service)
*/}}
{{- define "idem.imageTag" -}}
{{- $image := required (printf "services.%s.image is required" .name) .service.image -}}
{{- required (printf "services.%s.image.tag is required" .name) $image.tag | toString -}}
{{- end }}

{{/*
Образ сервиса с проверкой обязательных полей.
Вызов: include "idem.image" (dict "name" $name "service" $service)
*/}}
{{- define "idem.image" -}}
{{- $tag := include "idem.imageTag" . -}}
{{- $repo := required (printf "services.%s.image.repository is required" .name) .service.image.repository -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}
