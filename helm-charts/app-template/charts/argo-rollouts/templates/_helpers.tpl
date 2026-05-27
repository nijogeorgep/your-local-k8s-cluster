{{/*
Expand the name of the chart.
*/}}
{{- define "argo-rollouts.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "argo-rollouts.fullname" -}}
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
{{- define "argo-rollouts.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "argo-rollouts.labels" -}}
helm.sh/chart: {{ include "argo-rollouts.chart" . }}
{{ include "argo-rollouts.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "argo-rollouts.selectorLabels" -}}
app.kubernetes.io/name: {{ include "argo-rollouts.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the parent chart's fullname.
Priority:
  1. global.environment + global.flavor + global.region all set — <service>-<env>-<flavor>-<region>
  2. parentFullname explicit override
  3. Release.Name fallback
This helper is used to name the Rollout and all related test resources.
*/}}
{{- define "argo-rollouts.parentFullname" -}}
{{- if and .Values.global.environment .Values.global.region }}
{{- $svc := default .Release.Name .Values.nameOverride }}
{{- if .Values.global.flavor }}
{{- printf "%s-%s-%s-%s" $svc .Values.global.environment .Values.global.flavor .Values.global.region | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-%s" $svc .Values.global.environment .Values.global.region | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- else if .Values.parentFullname -}}
{{- .Values.parentFullname -}}
{{- else -}}
{{- .Release.Name -}}
{{- end -}}
{{- end -}}
