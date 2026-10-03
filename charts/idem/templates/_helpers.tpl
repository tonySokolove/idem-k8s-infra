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

{{/*
Values сервиса services.<name> в виде YAML. Падает, если нет services.<name>.enabled: обычно это значит, что
файл services/<name>.yaml не подключён в valueFiles (argocd/idem-dev.yaml) или в helm -f.
Громкая ошибка лучше, чем тихо пропавшие из рендера ресурсы, которые Argo CD удалит при Prune.
Вызов: include "idem.service.values" (dict "name" $name "root" $)
*/}}
{{- define "idem.service.values" -}}
{{- $service := index (.root.Values.services | default dict) .name | default dict -}}
{{- if not (hasKey $service "enabled") -}}
{{- fail (printf "services.%s.enabled is not set: add services/%s.yaml to valueFiles (argocd/idem-dev.yaml, helm -f)" .name .name) -}}
{{- end -}}
{{- toYaml $service -}}
{{- end }}
