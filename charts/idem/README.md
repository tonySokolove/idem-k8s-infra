# Helm chart `idem`

Один chart для всех сервисов IDEM в namespace `idem`. Argo CD Application — `argocd/idem-dev.yaml`.

## Где что лежит

```
charts/idem/
  values.yaml              # общее для всех: imagePullSecrets, ресурсы по умолчанию, квоты
  services/<service>.yaml  # всё о сервисе, что не зависит от среды: образ, порт, пробы, ресурсы, env
  envs/<env>.yaml          # только отличия среды: домены, секреты OpenBao, env этой среды (extraEnv)
  templates/
    <service>/             # ресурсы одного сервиса: deployment.yaml, service.yaml, ingress.yaml
    postgresql/            # StatefulSet, Services и внешний вход PostgreSQL
    platform/              # ExternalSecrets, LimitRange, ResourceQuota
    _deployment.tpl        # общие шаблоны типового HTTP-сервиса
    _service.tpl
    _ingress.tpl
    _helpers.tpl           # имена, метки, образ
```

**Версии образов** сервисов задаются в `argocd/idem-dev.yaml` → `spec.source.helm.parameters`
(`services.<service>.image.tag`). Их видно и можно менять в Argo CD: idem-dev → Details → Manifest.
Правка в UI меняет только Application в кластере — перенесите её в `argocd/idem-dev.yaml`,
иначе следующий `kubectl apply` этого файла вернёт старую версию.

Порядок значений (следующее перекрывает предыдущее):
`values.yaml` → `services/*.yaml` → `envs/<env>.yaml` → `helm.parameters`.

## Где менять

| Что | Файл |
| --- | --- |
| Версия образа | `argocd/idem-dev.yaml` → `parameters` (или Argo CD UI) |
| Переменная окружения, одинаковая во всех средах | `services/<service>.yaml` → `env` |
| Переменная, своя для среды | `envs/<env>.yaml` → `services.<service>.extraEnv` |
| Домен | `envs/<env>.yaml` → `services.<service>.ingress.host` |
| Ресурсы, порт, пробы | `services/<service>.yaml` |
| Секрет | значение — в OpenBao; путь — `envs/<env>.yaml` → `externalSecrets.secrets` |

Одна переменная — в одном месте: `env` и `extraEnv` склеиваются, дубли не перекрывают друг друга.

## Новый сервис

1. `services/<service>.yaml` — по образцу `services/check-in.yaml` (обязательно `enabled: true` и `image.repository`).
2. `templates/<service>/` — `deployment.yaml` и `service.yaml`, при внешнем адресе ещё `ingress.yaml`:
   ```
   {{ include "idem.deployment" (dict "name" "<service>" "root" $) }}
   ```
3. `envs/<env>.yaml` — домен, `extraEnv`, путь к секрету в `externalSecrets.secrets`.
4. `argocd/idem-dev.yaml` — добавить `services/<service>.yaml` в `valueFiles` и параметр
   `services.<service>.image.tag`.

Если файл сервиса забыли подключить или не задали тег, рендер падает с понятной ошибкой —
ресурсы не пропадают молча.

**Нетиповой сервис.** Общие шаблоны покрывают только типовой HTTP-сервис и не расширяются под
частные случаи. Нужен sidecar, volume, init-контейнер, свои пробы — замените `include` в папке
этого сервиса на его полный манифест. Остальные сервисы это не затронет.

## Проверка локально

PowerShell, из корня репозитория:

```powershell
$f = @()
Get-ChildItem charts/idem/services/*.yaml | ForEach-Object { $f += '-f', $_.FullName }
$f += '-f', 'charts/idem/envs/dev.yaml'
$tags = 'services.registrar.image.tag=0.1.2,services.check-in.image.tag=0.1.0,services.registration.image.tag=0.1.0'
helm lint charts/idem @f --set-string $tags
helm template idem-dev charts/idem --namespace idem @f --set-string $tags
```

После `git push`: если менялся `argocd/idem-dev.yaml` — `kubectl apply -f argocd/idem-dev.yaml`,
затем в Argo CD проверить Diff и сделать Sync (auto-sync выключен).
