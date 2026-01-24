{{- define "helloworld.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "helloworld.fullname" -}}
{{- printf "%s" (include "helloworld.name" .) -}}
{{- end -}}
