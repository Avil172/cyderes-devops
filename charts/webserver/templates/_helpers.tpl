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

{{- define "get-subnets" -}}
{{- $subnets := exec "aws" (list "eks" "describe-cluster" "--name" "funny-synth-duck" "--query" "cluster.resourcesVpcConfig.subnetIds" "--output" "text") | trim -}}
{{- $subnets | replace "\t" "," -}}
{{- end -}}