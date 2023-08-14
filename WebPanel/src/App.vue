<template data-theme="night">
  <header>
    <div class="navbar bg-base-100">
      <div class="navbar-start">
        <div class="dropdown">
          <label tabindex="0" class="btn btn-ghost btn-circle">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h7"
              />
            </svg>
          </label>
          <ul
            tabindex="0"
            class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-52"
          >
            <li><a>Leaderboard</a></li>
            <li><a>About</a></li>
          </ul>
        </div>
      </div>
      <div class="navbar-center">
        <a class="btn btn-ghost normal-case text-xl">TFDB Leaderboard</a>
      </div>
      <div class="navbar-end">
        <button class="btn">Login</button>
      </div>
    </div>
  </header>

  <div class="flex flex-col w-full border-opacity-50">
    <div class="grid h-60 card bg-base-300 rounded-box place-items-center">
      <article class="prose ">
        <h3 class="flex items-center justify-center">TF2 Dodgeball Rank Leaderboard System</h3>
        <div class="flex items-center justify-center">
          <p class="p-5">Highest Rocket Speed: <br>0.0f mph</p>
          <p class="p-2">First Place: <br>%N</p>
          <br>
          <p class="p-5">Amount of Players: <br>0</p>
        </div>
        </article>
    </div>
    <div class="divider">OR</div>
    <div class="flex items-center justify-center">
      <div class="">
        <strong class="p-5">Highest Rocket Speed: 0.0f mph<br></strong>
        <strong class="p-5">Leaderboard Position: 0<br></strong>
        <strong class="p-2">Kills: 0<br></strong>
        <strong class="p-2">Death: 0<br></strong>
        <strong class="p-2">Assists: 0<br></strong>
        <strong class="p-2">KDA: 0<br></strong>
      </div>
    </div>
  </div>
</template>
