{{- define "webserver.name" -}}
webserver
{{- end }}

{{- define "webserver.fullname" -}}
{{ include "webserver.name" . }}-app
{{- end }}
