{{/*
Expand the name of the chart.
*/}}
{{- define "todo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "todo-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "todo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "todo-app.labels" -}}
helm.sh/chart: {{ include "todo-app.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: todo-list-application
{{- end }}

{{/*
Frontend Selector labels
*/}}
{{- define "todo-app.frontendSelectorLabels" -}}
app: frontend
app.kubernetes.io/name: {{ include "todo-app.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend Selector labels
*/}}
{{- define "todo-app.backendSelectorLabels" -}}
app: backend
app.kubernetes.io/name: {{ include "todo-app.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MongoDB Selector labels
*/}}
{{- define "todo-app.mongodbSelectorLabels" -}}
app: mongodb
app.kubernetes.io/name: {{ include "todo-app.name" . }}-mongodb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret Name resolver
*/}}
{{- define "todo-app.secretName" -}}
{{- if .Values.mongodb.auth.existingSecret }}
{{- .Values.mongodb.auth.existingSecret }}
{{- else }}
{{- printf "%s-secret" (include "todo-app.fullname" .) }}
{{- end }}
{{- end }}
