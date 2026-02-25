FROM jenkins/jenkins:lts-jdk21

# Skip the initial setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Tell Jenkins where to find the JCasC config
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml

# Install plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy JCasC configuration
COPY casc.yaml /var/jenkins_home/casc.yaml

# Expose Jenkins web UI and agent communication ports
EXPOSE 8080 50000
