require "./jobs/update_worker"

namespace :stats do
  task :update do
    UpdateWorker.perform_async
  end
end
