# this file is maven DSL and used by maven via jars/executor.rb

basedir( ENV_JAVA[ "jars.basedir" ] )

( 0..10000 ).each do |i|
  coord = ENV_JAVA[ "jars.#{i}" ]
  break unless coord
  artifact = Maven::Tools::Artifact.from_coordinate( coord )
  exclusions = []
  ( 0..10000 ).each do |j|
    exclusion = ENV_JAVA[ "jars.#{i}.exclusions.#{j}" ]
    break unless exclusion
    exclusions << exclusion
  end
  scope = ENV_JAVA[ "jars.#{i}.scope" ]
  artifact.scope = scope if scope
  classifier = ENV_JAVA[ "jars.#{i}.classifier" ]
  artifact.classifier = classifier if classifier
  dependency_artifact( artifact ) do
    exclusions.each do |ex|
      exclusion ex
    end
  end
end

jruby_plugin :gem, ENV_JAVA[ "jruby.plugins.version" ]

jfile = ENV_JAVA[ "jars.jarfile" ]
jarfile( jfile ) if jfile


# if you use bundler we collect all root jar dependencies
# from each gemspec file. otherwise we need to resolve
# the gemspec artifact in the maven way
unless ENV_JAVA[ "jars.bundler" ]

  gemspec rescue nil

end

properties( 'project.build.sourceEncoding' => 'utf-8' )

plugin :dependency, ENV_JAVA[ "dependency.plugin.version" ]

# some output
model.dependencies.each do |d|
  puts "      " + d.group_id + ':' + d.artifact_id + (d.classifier ? ":" + d.classifier : "" ) + ":" + d.version + ':' + (d.scope || 'compile')
  puts "          exclusions: " + d.exclusions.collect{ |e| e.group_id + ':' + e.artifact_id }.join unless d.exclusions.empty?
end
