{{/*
Create the name of the service account to use
*/}}
{{- define "breeze-agent.serviceAccount" -}}
{{- if .Values.serviceAccount.create -}}
{{ default .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{/*
Create the name of the cluster role to use
*/}}
{{- define "breeze-agent.clusterRoleName" -}}
{{- if .Values.clusterRoleName.create -}}
{{ default .Values.clusterRoleName.name }}
{{- else -}}
    {{ default "default" .Values.clusterRoleName.name }}
{{- end -}}
{{- end -}}
