Code.require_file "../../../test_helper", __FILE__

defmodule Mix.Tasks.DepsTest do
  use MixTest.Case

  defmodule DepsApp do
    def project do
      [
        deps: [
          { :ok, "0.1.0",         git: "https://github.com/elixir-lang/ok.git" },
          { :invalidvsn, "0.2.0", git: "https://github.com/elixir-lang/invalidvsn.git" },
          { :invalidapp, "0.1.0", git: "https://github.com/elixir-lang/invalidapp.git" },
          { :noappfile, "0.1.0",  git: "https://github.com/elixir-lang/noappfile.git" },
          { :uncloned,            git: "https://github.com/elixir-lang/uncloned.git" }
        ]
      ]
    end
  end

  defmodule GetApp do
    def project do
      [
        deps: [
          { :git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo") }
        ]
      ]
    end
  end

  defmodule SuccessfulDepsApp do
    def project do
      [
        deps: [
          { :ok, "0.1.0", git: "https://github.com/elixir-lang/ok.git" }
        ]
      ]
    end
  end

  defmodule UnclonedDepsApp do
    def project do
      [
        deps: [
          { :uncloned, "0.1.0",   git: "https://github.com/elixir-lang/uncloned.git" }
        ]
      ]
    end
  end

  defmodule RegexDepsApp do
    def project do
      [
        deps: [
          { :ok, %r"^0\.{1,2}",    git: "https://github.com/elixir-lang/ok.git" },
          { :invalidvsn, %r"^2.0", git: "https://github.com/elixir-lang/invalidvsn.git" }
        ]
      ]
    end
  end

  defmodule GetErrorApp do
    def project do
      [
        deps: [
          { :git_repo, "0.1.0", git: MixTest.Case.fixture_path("not_git_repo") }
        ]
      ]
    end
  end

  test "prints list of dependencies and their status" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.run []

      assert_received { :mix_shell, :info, ["* ok (0.1.0) [git: \"https://github.com/elixir-lang/ok.git\"]"] }
      assert_received { :mix_shell, :info, ["  ok"] }
      assert_received { :mix_shell, :info, ["* invalidvsn [git: \"https://github.com/elixir-lang/invalidvsn.git\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency does not match the specified version, got 0.1.0"] }
      assert_received { :mix_shell, :info, ["* invalidapp [git: \"https://github.com/elixir-lang/invalidapp.git\"]"] }
      assert_received { :mix_shell, :info, ["  the app file at deps/invalidapp/ebin/invalidapp.app is invalid"] }
      assert_received { :mix_shell, :info, ["* noappfile [git: \"https://github.com/elixir-lang/noappfile.git\"]"] }
      assert_received { :mix_shell, :info, ["  could not find app file at deps/noappfile/ebin/noappfile.app"] }
      assert_received { :mix_shell, :info, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency is not available, run `mix deps.get`"] }
    end
  after
    Mix.Project.pop
  end

  test "prints list of dependencies and their status including regex matches" do
    Mix.Project.push RegexDepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.run []

      assert_received { :mix_shell, :info, ["* ok (0.1.0) [git: \"https://github.com/elixir-lang/ok.git\"]"] }
      assert_received { :mix_shell, :info, ["  ok"] }
      assert_received { :mix_shell, :info, ["* invalidvsn [git: \"https://github.com/elixir-lang/invalidvsn.git\"]"] }
      assert_received { :mix_shell, :info, ["  the dependency does not match the specified version, got 0.1.0"] }
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status on success" do
    Mix.Project.push SuccessfulDepsApp

    in_fixture "deps_status", fn ->
      Mix.Tasks.Deps.Check.run []
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status on first run" do
    Mix.Project.push UnclonedDepsApp

    in_fixture "deps_status", fn ->
      assert_raise Mix.NotMetDepsError, "Dependencies are not available, run `mix deps.get` before proceeding", fn ->
        Mix.Tasks.Deps.Check.run []
      end

      refute_received { :mix_shell, :error, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
      refute_received { :mix_shell, :error, ["  the dependency is not available, run `mix deps.get`"] }
    end
  after
    Mix.Project.pop
  end

  test "check list of dependencies and their status on failure" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      assert_raise Mix.NotMetDepsError, fn ->
        Mix.Tasks.Deps.Check.run []
      end

      refute_received { :mix_shell, :error, ["* ok (0.1.0) [git: \"https://github.com/elixir-lang/ok.git\"]"] }
      refute_received { :mix_shell, :error, ["  ok"] }

      assert_received { :mix_shell, :error, ["* invalidvsn [git: \"https://github.com/elixir-lang/invalidvsn.git\"]"] }
      assert_received { :mix_shell, :error, ["  the dependency does not match the specified version, got 0.1.0"] }
      assert_received { :mix_shell, :error, ["* invalidapp [git: \"https://github.com/elixir-lang/invalidapp.git\"]"] }
      assert_received { :mix_shell, :error, ["  the app file at deps/invalidapp/ebin/invalidapp.app is invalid"] }
      assert_received { :mix_shell, :error, ["* noappfile [git: \"https://github.com/elixir-lang/noappfile.git\"]"] }
      assert_received { :mix_shell, :error, ["  could not find app file at deps/noappfile/ebin/noappfile.app"] }
      assert_received { :mix_shell, :error, ["* uncloned [git: \"https://github.com/elixir-lang/uncloned.git\"]"] }
      assert_received { :mix_shell, :error, ["  the dependency is not available, run `mix deps.get`"] }
    end
  after
    Mix.Project.pop
  end

  test "get, update and clean git repos with compilation" do
    Mix.Project.push GetApp

    in_fixture "no_mixfile", fn ->
      Mix.Tasks.Deps.Get.run []
      message = "* Getting git_repo [git: #{inspect fixture_path("git_repo")}]"
      assert_received { :mix_shell, :info, [^message] }
      assert_received { :mix_shell, :info, ["* Compiling git_repo"] }
      assert_received { :mix_shell, :info, ["Compiled lib/git_repo.ex"] }
      assert_received { :mix_shell, :info, ["Generated git_repo.app"] }
      assert File.exists?("deps/git_repo/ebin/Elixir-GitRepo.beam")
      assert File.read!("mix.lock") =~ %r("git_repo": "[a-f0-9]+")

      purge [GitRepo, GitRepo.Mix]
      File.touch!("deps/git_repo/ebin", { { 2010, 4, 17 }, { 14, 0, 0 } })
      Mix.Task.clear

      Mix.Tasks.Deps.Update.run []
      message = "* Updating git_repo (0.1.0) [git: #{inspect fixture_path("git_repo")}]"
      assert_received { :mix_shell, :info, [^message] }
      assert_received { :mix_shell, :info, ["* Compiling git_repo"] }
      assert_received { :mix_shell, :info, ["Compiled lib/git_repo.ex"] }

      Mix.Tasks.Deps.Clean.run []
      message = "* Cleaning git_repo (0.1.0) [git: #{inspect fixture_path("git_repo")}]"
      assert_received { :mix_shell, :info, [^message] }
      refute File.exists?("deps/git_repo/ebin/Elixir-Git-Repo.beam")
    end
  after
    purge [GitRepo, GitRepo.Mix]
    Mix.Project.pop
  end

  test "does not attempt to compile projects that could not be retrieved" do
    Mix.Project.push GetErrorApp

    in_fixture "no_mixfile", fn ->
      Mix.Tasks.Deps.Get.run []
      message = "* Getting git_repo [git: #{inspect fixture_path("not_git_repo")}]"
      assert_received { :mix_shell, :info, [^message] }
      assert_received { :mix_shell, :error, _ }
    end
  after
    Mix.Project.pop
  end
end