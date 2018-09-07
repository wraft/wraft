defmodule StarterWeb.PropicUploader do
    use Arc.Definition
    use Arc.Ecto.Definition
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
        file_name = Path.basename(file.file_name, Path.extname(file.file_name))
        "profilepic_#{user.firstname}"
        # IEx.pry
      end
      
      #Storage Directory
      def storage_dir(_, {file, user}) do
        "uploads/avatars/#{user.id}"
      end
end