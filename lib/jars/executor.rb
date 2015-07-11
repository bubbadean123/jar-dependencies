require 'maven/ruby/maven'
require 'fileutils'
require 'jar_dependencies'
require 'jars/version'

module Jars
  class Executor

    attr_reader :debug, :verbose

    def initialize( debug = false, verbose = false )
      @debug = debug
      @verbose = verbose
    end

    def maven_new
      m = Maven::Ruby::Maven.new
      m.property( 'jruby.plugins.version', Jars::JRUBY_PLUGINS_VERSION )
      m.property( 'dependency.plugin.version', Jars::DEPENDENCY_PLUGIN_VERSION )
      m.property( 'jars.basedir', File.expand_path( basedir ) )
      m.property( 'jars.jarfile', File.expand_path( Jars.jarfile ) )
      m.property( 'verbose', (debug || verbose) == true )
      if debug
        m.options[ '-X' ] = nil
      elsif verbose
        m.options[ '-e' ] = nil
      else
        m.options[ '-q' ] = nil
      end
      m.verbose = debug
      attach_jar_coordinates_from_bundler_dependencies( m )
      m
    end
    private :maven_new

    def maven
      @maven ||= maven_new
    end

    def basedir
      File.expand_path( '.' )
    end

    def exec( *args )
      maven.options[ '-f' ] = File.expand_path( '../lock_down_pom.rb', __FILE__ )
      maven.exec( *args )
    end

    def attach_jar_coordinates_from_bundler_dependencies( maven )
      load_path = $LOAD_PATH.dup
      require 'bundler/setup'
      done = []
      index = 0
      Gem.loaded_specs.each do |name, spec|
        deps = GemspecArtifacts.new( spec )
        deps.artifacts.each do |a|
          unless done.include? a.key
            maven.property( "jars.#{index}", a.to_gacv )
            if a.exclusions
              jndex = 0
              a.exclusions.each do |ex|
                maven.property( "jars.#{index}.exclusions.#{jndex}", ex.to_s )
              end
            end
            maven.property( "jars.#{index}.scope", a.scope )
            index += 1
            done << a.key
          end
        end
      end
    rescue LoadError
      warn "no bundler found - ignore Gemfile if exists"
    ensure
      $LOAD_PATH.replace( load_path )
    end

    def lock_down( options = {} )
      vendor_dir = File.expand_path( options[ :vendor_dir ] ) if options[ :vendor_dir ]
      out = File.expand_path( '.jars.output' )
      tree = File.expand_path( '.jars.tree' )
      maven.property( 'jars.outputFile', out )
      maven.property( 'maven.repo.local', Jars.home )
      maven.property( 'jars.home', vendor_dir ) if vendor_dir
      maven.property( 'jars.lock', File.expand_path( Jars.lock ) )
      maven.property( 'jars.force', options[ :force ] == true )
      maven.property( 'jars.update', options[ :update ] ) if options[ :update ]

      args = [ 'gem:jars-lock' ]
      if options[ :tree ]
        args += [ 'dependency:tree', '-P -gemfile.lock', '-DoutputFile=' + tree ]
      end

      puts
      puts '-- jar root dependencies --'
      puts
      status = exec( *args )
      exit 1 unless status
      if File.exists?( tree )
        puts
        puts '-- jar dependency tree --'
        puts
        puts File.read( tree )
        puts
      end
      puts
      puts File.read( out ).gsub( /#{File.dirname(out)}\//, '' )
      puts
    ensure
      FileUtils.rm_f out
      FileUtils.rm_f tree
    end
  end
end
