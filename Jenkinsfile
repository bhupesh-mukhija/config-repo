pipeline {
  // this build can be run on any agent more relevant for master, slave, windows and linux env etc.
  agent any
  
  // actual work happens
  stages {
    
    stage('authenticate') {
      steps {
        sh echo 'identify orgs to authenticate'
      }
      
      steps {
        sh echo 'authenticate to required orgs'
      }
    }
    
    stage('prepare environment') {
      steps {
        sh echo 'identify dependencies'
      }
      
      steps {
        sh echo 'create org'
      }
      
      steps {
        sh echo 'install dependencies'
      }
    }
    
    stage('validate') {
      steps {
        sh echo 'validate manifest'
      }
      
      steps {
        sh echo 'run tests'
      }
    }
    
    stage('deploy in scratch') {
      steps {
        sh echo 'deploy application'
      }
    }
  }
}

/*node {
  // groovy script
}*/
