{{/*
Expand the name of the chart.
*/}}
{{- define "opensas-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opensas-infra.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opensas-infra.labels" -}}
helm.sh/chart: {{ include "opensas-infra.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "opensas-infra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: opensas
{{- end }}

{{/*
vLLM selector labels
*/}}
{{- define "opensas-infra.vllm.selectorLabels" -}}
app.kubernetes.io/name: vllm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: inference
{{- end }}

{{/*
LiteLLM selector labels
*/}}
{{- define "opensas-infra.litellm.selectorLabels" -}}
app.kubernetes.io/name: litellm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: api-gateway
{{- end }}

{{/*
Langfuse selector labels
*/}}
{{- define "opensas-infra.langfuse.selectorLabels" -}}
app.kubernetes.io/name: langfuse
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: observability
{{- end }}

{{/*
Langfuse Postgres selector labels
*/}}
{{- define "opensas-infra.langfuse-postgres.selectorLabels" -}}
app.kubernetes.io/name: langfuse-postgresql
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Generate vLLM model argument string
*/}}
{{- define "opensas-infra.vllm.modelArgs" -}}
{{- $models := .Values.vllm.models | default list -}}
{{- if $models -}}
{{- $names := list -}}
{{- range $models -}}
{{- $names = append $names .name -}}
{{- end -}}
{{- join "," $names -}}
{{- end -}}
{{- end -}}
