{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "csis.name" -}}
{{- default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

# Database name
{{- define "csis.dbName" -}}
{{- printf "%s_%s" $.Release.Name $.Values.csis.environment | replace "-" "_" -}}
{{- end -}}

# Volumes names
{{- define "csis.storageVolumeName" -}}
{{- $.Values.csis.volumes.storage.name | default (printf "%s-storage-pvc" ($.Release.Name)) -}}
{{- end -}}
{{- define "csis.dbVolumeName" -}}
{{- $.Values.csis.volumes.db.name | default (printf "%s-db-pvc" ($.Release.Name)) -}}
{{- end -}}
{{- define "csis.assetsVolumeName" -}}
{{- $.Values.csis.volumes.assets.name | default (printf "%s-assets-pvc" ($.Release.Name)) -}}
{{- end -}}
{{- define "csis.redisVolumeName" -}}
{{- $.Values.csis.volumes.redis.name | default (printf "%s-redis-pvc" ($.Release.Name)) -}}
{{- end -}}
{{- define "csis.gpgVolumeName" -}}
{{- $.Values.csis.volumes.gpg.name | default (printf "%s-gpg-pvc" ($.Release.Name)) -}}
{{- end -}}


{{/* Registry/app-path */}}
{{- define "csis.appRegistry" -}}
{{ print .Values.csis.image.registry "/csis-app" }}
{{- end -}}
{{/* App Version allowing specific version override */}}
{{- define "csis.appVersion" -}}
{{ .Values.csis.version | default .Chart.AppVersion }}
{{- end -}}
{{/* AppRegistry:AppVersion*/}}
{{- define "csis.appImage" -}}
{{ include "csis.appRegistry" . }}:{{ include "csis.appVersion" . }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "csis.fullname" -}}
{{- if $.Values.fullnameOverride -}}
{{- $.Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default $.Chart.Name $.Values.nameOverride -}}
{{- if contains $name $.Release.Name -}}
{{- $.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "csis.chart" -}}
{{- printf "%s-%s" $.Chart.Name $.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "csis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "csis.name" . }}
app.kubernetes.io/instance: {{ $.Release.Name }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "csis.labels" -}}
helm.sh/chart: {{ include "csis.chart" . }}
{{ include "csis.selectorLabels" . }}
app.kubernetes.io/version: {{ $.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $.Release.Service }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "csis.serviceAccountName" -}}
{{- if $.Values.serviceAccount.create -}}
    {{ default (include "csis.fullname" .) $.Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" $.Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
  Generate the .dockerconfigjson file unencoded.
*/}}
{{- define "dockerconfigjson.plain" }}
  {{- with $.Values.csis.image }}
    {{- print "{\"auths\":{" }}
      {{- print "\"https://" .registry "\":{" }}
      {{- printf "\"auth\":\"%s\"}" (printf "%s:%s" .registryUsername .registryPassword | b64enc) }}
    {{- print "}}" }}
  {{- end }}
{{- end }}

{{/*
  Generate the base64-encoded .dockerconfigjson.
  See https://github.com/helm/helm/issues/3691#issuecomment-386113346
*/}}
{{- define "dockerconfigjson.b64enc" }}
  {{- include "dockerconfigjson.plain" . | b64enc }}
{{- end }}
