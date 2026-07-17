FROM eclipse-temurin:17-jre

WORKDIR /app

COPY spring-petclinic-3.3.0.jar app.jar
COPY jmx_prometheus_javaagent-1.0.1.jar /opt/jmx_exporter.jar
COPY config.yaml /opt/config.yaml

EXPOSE 8080
EXPOSE 9404

ENTRYPOINT ["java","-javaagent:/opt/jmx_exporter.jar=9404:/opt/config.yaml","-jar","/app/app.jar"]
