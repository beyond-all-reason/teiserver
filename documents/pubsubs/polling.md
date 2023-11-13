#### polling_surveys
Used to communicate updates and changes to a survey potentially changing the contents of a page
```elixir
%{
  event: :survey_created
  survey: Survey object
}

%{
  event: :survey_updated
  survey: Survey object
}

%{
  event: :survey_deleted
  survey: Survey object
}


# While questions these are still sent as part of a survey as our pages would always be referencing the survey as a whole not individual questions.
%{
  event: :question_created
  question: Question object
}

%{
  event: :question_updated
  question: Question object
}

%{
  event: :question_deleted
  question: Question object
}
```
