Pod::Spec.new do |s|

  s.name         = "SGVReachability"
  s.version      = "1.0.0"
  s.summary      = "Simple reachability wrapper for iOS."

  s.description  = <<-DESC
                    Simple reachability wrapper for iOS.
                    
                    * Thread-safe
                    * Non-blocking
                    * Provides access to raw reachability flags structure
                    * Can post notifications on reachability change to a given NSOperationQueue
                   DESC

  s.homepage     = "https://github.com/sanekgusev/SGVReachability"

  s.license      = "MIT"
  
  s.author             = { "Alexander Gusev" => "sanekgusev@gmail.com" }
  s.social_media_url   = "http://twitter.com/sanekgusev"

  s.platform     = :ios, "4.3"

  s.source       = { :git => "https://github.com/sanekgusev/SGVReachability.git", :tag => "1.0.0" }

  s.source_files  = "src"

  s.frameworks = "Foundation", "SystemConfiguration"

  s.requires_arc = true

end
