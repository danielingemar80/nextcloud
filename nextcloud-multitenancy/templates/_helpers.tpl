{{/*
=============================================================================
_helpers.tpl — shared template helpers
=============================================================================
*/}}

{{/*
Expand the chart name.
*/}}
{{- define "nextcloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nextcloud.fullname" -}}
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
Chart label (name + version).
*/}}
{{- define "nextcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (tenant-aware).
Usage: include "nextcloud.labels" (dict "tenant" $tenant "root" $)
*/}}
{{- define "nextcloud.labels" -}}
helm.sh/chart: {{ include "nextcloud.chart" .root }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/part-of: nextcloud-multitenancy
{{- if .tenant }}
app.kubernetes.io/instance: {{ printf "%s-%s" .root.Release.Name .tenant.name | trunc 63 }}
app.kubernetes.io/name: {{ printf "nextcloud-%s" .tenant.name | trunc 63 }}
tenant: {{ .tenant.name }}
{{- end }}
{{- end }}

{{/*
Selector labels (tenant-aware).
*/}}
{{- define "nextcloud.selectorLabels" -}}
{{- if .tenant }}
app.kubernetes.io/name: {{ printf "nextcloud-%s" .tenant.name | trunc 63 }}
app.kubernetes.io/instance: {{ printf "%s-%s" .root.Release.Name .tenant.name | trunc 63 }}
tenant: {{ .tenant.name }}
{{- end }}
{{- end }}

{{/*
Redis labels
*/}}
{{- define "redis.labels" -}}
helm.sh/chart: {{ include "nextcloud.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}-redis
app.kubernetes.io/part-of: nextcloud-multitenancy
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}-redis
{{- end }}

{{/*
Service account name
*/}}
{{- define "nextcloud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nextcloud.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Redis service name
*/}}
{{- define "redis.serviceName" -}}
{{- printf "%s-redis" .Release.Name }}
{{- end }}

{{/*
Render resource block for a tenant (falls back to empty if not set)
*/}}
{{- define "tenant.resources" -}}
{{- if .tenant.resources }}
resources:
  {{- toYaml .tenant.resources | nindent 2 }}
{{- end }}
{{- end }}
