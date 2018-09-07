defmodule StarterWeb.WorkFileUploader do
    use Arc.Definition
    use Arc.Ecto.Definition
    alias Starter.{UserManagement.User, Repo}
require IEx
    @versions [:original]
    @extension_whitelist ~w(.jpg .jpeg .gif .png)

#Validate Filetype
    def validate({file, _}) do
        file_extension = 
          file.file_name 
          |> Path.extname
          |> String.downcase
        Enum.member?(@extension_whitelist, file_extension)
      end

      #Change Filename
    def filename(version, {file, user}) do
        user_id = user.user_id
        user_struct = Repo.get(User, user_id)
        
        file_name = Path.basename(file.file_name, Path.extname(file.file_name))
        "workfile_#{user_struct.firstname}_#{user_struct.updated_at}"
      end
      
      #Storage Directory
      def storage_dir(_, {file, user}) do
        user_id = user.user_id
        user_struct = Repo.get(User, user_id)

        "uploads/work/#{user_struct.id}"
      end
end