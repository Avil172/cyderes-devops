{{- define "nginx.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "nginx.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "nginx.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}
