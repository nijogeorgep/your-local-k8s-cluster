{{/*
Expand the name of the chart.
*/}}
{{- define "istio-routing.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Priority:
  1. fullnameOverride — used as-is
  2. global.environment + global.flavor + global.region all set — <service>-<env>-<flavor>-<region>
  3. Standard Helm logic
Applies to: VirtualService, DestinationRule, and all other Istio resources.
*/}}
{{- define "istio-routing.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if and .Values.global.environment .Values.global.region }}
{{- $svc := default .Release.Name .Values.nameOverride }}
{{- if .Values.global.flavor }}
{{- printf "%s-%s-%s-%s" $svc .Values.global.environment .Values.global.flavor .Values.global.region | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-%s" $svc .Values.global.environment .Values.global.region | trunc 63 | trimSuffix "-" }}
{{- end }}
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
{{- define "istio-routing.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "istio-routing.labels" -}}
helm.sh/chart: {{ include "istio-routing.chart" . }}
{{ include "istio-routing.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "istio-routing.selectorLabels" -}}
app.kubernetes.io/name: {{ include "istio-routing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
