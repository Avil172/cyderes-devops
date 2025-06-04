{{- define "webserver.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "webserver.labels" -}}
app.kubernetes.io/name: {{ include "webserver.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "webserver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webserver.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}