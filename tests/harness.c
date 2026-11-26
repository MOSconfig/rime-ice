// Regression harness: drive librime with key sequences and print candidates.
// Usage: harness <user_dir> <shared_dir> <schema_id> < keys.txt
// Input line:  [+option,-option:]keys     e.g. "+traditionalization:zhongguo"
// Output line: input<TAB>commit<TAB>cand1<TAB>...<TAB>cand5
// user_dir must be a scratch copy of the config (it receives build/ output);
// shared_dir is only read (e.g. Squirrel's SharedSupport). Never point
// user_dir at the live Rime user folder.
#include <stdio.h>
#include <string.h>
#include "rime_api.h"

// Apply "+opt,-opt" for one row; remember prior values so they can be restored.
#define MAX_OPTS 8
typedef struct { char name[64]; Bool prior; } SavedOpt;

static int set_options(RimeApi* rime, RimeSessionId s, const char* spec, SavedOpt* saved) {
  char buf[256];
  snprintf(buf, sizeof buf, "%s", spec);
  int n = 0;
  for (char* opt = strtok(buf, ","); opt && n < MAX_OPTS; opt = strtok(NULL, ",")) {
    if (opt[0] != '+' && opt[0] != '-') continue;
    snprintf(saved[n].name, sizeof saved[n].name, "%s", opt + 1);
    saved[n].prior = rime->get_option(s, saved[n].name);
    rime->set_option(s, saved[n].name, opt[0] == '+');
    n++;
  }
  return n;
}

static void restore_options(RimeApi* rime, RimeSessionId s, SavedOpt* saved, int n) {
  for (int i = n - 1; i >= 0; i--) rime->set_option(s, saved[i].name, saved[i].prior);
}

int main(int argc, char** argv) {
  if (argc < 4) {
    fprintf(stderr, "usage: %s user_dir shared_dir schema_id < keys\n", argv[0]);
    return 2;
  }
  RimeApi* rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.user_data_dir = argv[1];
  traits.shared_data_dir = argv[2];
  traits.app_name = "rime.config-tests";
  traits.min_log_level = 1;  // warnings and errors
  traits.log_dir = "";       // log to stderr
  rime->setup(&traits);
  rime->initialize(&traits);
  if (rime->start_maintenance(True)) rime->join_maintenance_thread();

  RimeSessionId s = rime->create_session();
  if (!s || !rime->select_schema(s, argv[3])) {
    fprintf(stderr, "cannot select schema %s\n", argv[3]);
    return 1;
  }
  char line[1024];
  SavedOpt saved[MAX_OPTS];
  while (fgets(line, sizeof line, stdin)) {
    line[strcspn(line, "\r\n")] = 0;
    if (!line[0]) continue;
    char* keys = line;
    int nsaved = 0;
    char* colon = (line[0] == '+' || line[0] == '-') ? strchr(line, ':') : NULL;
    if (colon) {
      *colon = 0;
      nsaved = set_options(rime, s, line, saved);
      *colon = ':';
      keys = colon + 1;
    }
    rime->clear_composition(s);
    rime->simulate_key_sequence(s, keys);
    printf("%s\t", line);
    RIME_STRUCT(RimeCommit, commit);
    if (rime->get_commit(s, &commit)) {
      printf("%s", commit.text ? commit.text : "");
      rime->free_commit(&commit);
    }
    RIME_STRUCT(RimeContext, ctx);
    if (rime->get_context(s, &ctx)) {
      for (int i = 0; i < ctx.menu.num_candidates && i < 5; i++)
        printf("\t%s", ctx.menu.candidates[i].text);
      rime->free_context(&ctx);
    }
    printf("\n");
    restore_options(rime, s, saved, nsaved);
  }
  rime->destroy_session(s);
  rime->finalize();
  return 0;
}
